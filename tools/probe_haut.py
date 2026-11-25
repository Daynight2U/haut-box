#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
HAUT 教务系统接口探测脚本（零依赖，纯标准库，Python 3.8+ 直接跑）

用途：登录 http://jwglxt.haut.edu.cn 的正方教务系统，抓取
      学生信息 / 课表 / 成绩 / 考试 的原始 JSON，落盘到 ./out/ 供开发对接。

用法：
    python probe_haut.py 学号 密码
    python probe_haut.py            # 交互式输入（密码不回显）

安全说明：
    - 只在内存里用密码登录一次，脚本不保存密码、不写日志；
    - 只读接口，不选课、不改任何数据；
    - 结果只写在你本机 ./out/ 目录。
"""

import base64
import http.cookiejar
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request

BASE = "https://jwglxt.haut.edu.cn"
CTX = "/jwglxt"
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36")

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")


# ---------------------------------------------------------------- 基础 HTTP
class Session:
    def __init__(self):
        self.cj = http.cookiejar.CookieJar()
        self.opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(self.cj))
        self.opener.addheaders = [
            ("User-Agent", UA),
            ("Accept-Language", "zh-CN,zh;q=0.9"),
            ("Accept", "text/html,application/xhtml+xml,application/json,*/*"),
        ]

    def open(self, path, data=None, headers=None, raw_body=None):
        url = path if path.startswith("http") else BASE + path
        body = None
        if raw_body is not None:
            body = raw_body
        elif data is not None:
            body = urllib.parse.urlencode(data).encode()
        req = urllib.request.Request(url, data=body)
        if body is not None:
            req.add_header("Content-Type", "application/x-www-form-urlencoded; charset=UTF-8")
        req.add_header("X-Requested-With", "XMLHttpRequest")
        req.add_header("Referer", BASE + CTX + "/xtgl/login_slogin.html")
        for k, v in (headers or {}).items():
            req.add_header(k, v)
        try:
            resp = self.opener.open(req, timeout=30)
            return resp.getcode(), resp.read().decode("utf-8", "replace"), resp.geturl()
        except urllib.error.HTTPError as e:
            return e.code, e.read().decode("utf-8", "replace"), url


# ------------------------------------------------------------ 纯 Python RSA
def rsa_encrypt_pkcs1v15(plain: bytes, modulus_b64: str, exponent_b64: str) -> str:
    """复刻正方前端的 RSA/ECB/PKCS1Padding（公钥 modulus/exponent 均为 base64 大端字节）"""
    n = int.from_bytes(base64.b64decode(modulus_b64), "big")
    e = int.from_bytes(base64.b64decode(exponent_b64), "big")
    k = (n.bit_length() + 7) // 8
    if len(plain) > k - 11:
        raise ValueError("password too long")
    # PKCS#1 v1.5: 0x00 || 0x02 || PS(随机非零) || 0x00 || M
    ps = bytearray()
    while len(ps) < k - len(plain) - 3:
        b = os.urandom(1)[0]
        if b:
            ps.append(b)
    block = b"\x00\x02" + bytes(ps) + b"\x00" + plain
    m = int.from_bytes(block, "big")
    c = pow(m, e, n)
    return base64.b64encode(c.to_bytes(k, "big")).decode()


# ------------------------------------------------------------------ 登录
def login(s, username, password):
    code, html, _ = s.open(CTX + "/xtgl/login_slogin.html")
    if code != 200:
        raise RuntimeError("登录页不可达 HTTP %s" % code)

    m = re.search(r'id="csrftoken"[^>]*value="([^"]+)"', html)
    if not m:
        raise RuntimeError("未找到 csrftoken，页面结构可能已变更")
    # 正方是原生 form.submit()，csrftoken 原样提交（形如 "uuid,去横线uuid"），不能截断
    token = m.group(1)

    # 页面标记：是否需要验证码 / 密码是否加密
    flags = {k: (re.search(r'id="%s"[^>]*value=\s*"?([^"\s>]*)"?' % k, html) or [None, "?"])[1]
             for k in ("dlsfbxyzm", "mmsfjm", "yzcskz", "sfxswechatlogin")}
    print("  [页面标记] 需要验证码=%s  密码加密=%s  错误次数控制=%s  微信登录=%s"
          % (flags["dlsfbxyzm"], flags["mmsfjm"], flags["yzcskz"], flags["sfxswechatlogin"]))

    code, pk, _ = s.open(CTX + "/xtgl/login_getPublicKey.html?time=%d" % int(time.time() * 1000))
    if code != 200:
        raise RuntimeError("公钥接口异常 HTTP %s" % code)
    j = json.loads(pk)
    mm = rsa_encrypt_pkcs1v15(password.encode(), j["modulus"], j["exponent"])

    code, html, url = s.open(
        CTX + "/xtgl/login_slogin.html?time=%d" % int(time.time() * 1000),
        data={"yhm": username, "mm": mm, "csrftoken": token, "language": "zh_CN"},
    )
    text = html
    if "用户名或密码不正确" in text or "用户不存在" in text:
        raise RuntimeError("登录失败：用户名或密码不正确")
    if "验证码" in text and "login_slogin" in url:
        with open(os.path.join(OUT_DIR, "login_fail.html"), "w", encoding="utf-8") as f:
            f.write(text)
        raise RuntimeError("登录被拦截（可能需要验证码/密码错误次数过多），已保存 login_fail.html")

    # 验证会话是否真的建立
    code, menu, _ = s.open(CTX + "/xtgl/index_initMenu.html?jsdm=&_t=%d" % int(time.time() * 1000))
    ok = code == 200 and "login_slogin" not in _
    print("  [会话] index_initMenu HTTP %s -> %s" % (code, "已登录" if ok else "未登录(仍跳登录页)"))
    if not ok:
        raise RuntimeError("登录后仍未建立会话")
    return menu


# ------------------------------------------------------------ 数据接口
def dump(name, obj):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name)
    with open(path, "w", encoding="utf-8") as f:
        if isinstance(obj, (dict, list)):
            json.dump(obj, f, ensure_ascii=False, indent=2)
        elif obj is None:
            f.write("null")
        else:
            f.write(obj)
    print("  [落盘] %s" % path)


def cur_term():
    """本地推算当前学期：8 月起算新学年第一学期；2~7 月算第二学期"""
    now = time.localtime()
    if now.tm_mon >= 8:
        return str(now.tm_year), "3"
    if now.tm_mon <= 1:
        return str(now.tm_year - 1), "3"
    return str(now.tm_year - 1), "12"


def try_json(name, path, data):
    s = SESSION
    code, text, url = s.open(path, data=data)
    snippet = text[:200].replace("\n", " ")
    if "login_slogin" in url or "login_slogin" in snippet:
        print("  [%s] HTTP %s 会话失效/被重定向" % (name, code))
        dump(name + ".html", text)
        return None
    try:
        obj = json.loads(text)
    except Exception:
        print("  [%s] HTTP %s 非 JSON，首 200 字：%s" % (name, code, snippet))
        dump(name + ".html", text)
        return None
    dump(name + ".json", obj)
    return obj


def fetch_student_info():
    print("[1/5] 学生信息")
    menu = SESSION_LAST_MENU
    # 从菜单页/首页里正则抓学号姓名兜底
    m = re.search(r"([\u4e00-\u9fa5]{2,4})\s*[,，]\s*(\d{8,14})", menu)
    if m:
        print("  菜单页识别到：%s %s" % (m.group(1), m.group(2)))
    obj = try_json("student_info",
                   CTX + "/xsxxxggl/xsxxwh_cxXsxx.html?gnmkdm=N100801",
                   {"xnm": "", "xqm": ""})
    # 课程表接口里也带 xsxx（学生信息 + 学期列表），这里一并取
    return obj


def fetch_schedule(xnm="", xqm=""):
    if not xnm:
        xnm, xqm = cur_term()          # 实测：不传学期接口直接返回 null
    print("[2/5] 课表  xnm=%s xqm=%s" % (xnm or "(当前)", xqm or "(当前)"))
    obj = try_json("schedule_%s_%s" % (xnm or "cur", xqm or "cur"),
                   CTX + "/kbcx/xskbcx_cxXsKb.html?gnmkdm=N2151",
                   {"xnm": xnm, "xqm": xqm, "kzlx": "ck"})
    if isinstance(obj, dict):
        xsxx = obj.get("xsxx") or {}
        kb = obj.get("kbList") or []
        print("  学生：%s  %s  课表条数：%d" % (xsxx.get("XM"), xsxx.get("XH"), len(kb)))
        if kb:
            c = kb[0]
            print("  首条课程字段样例：%s" % ", ".join(sorted(c.keys())))
            print("  例：%s / %s / %s / 周次%s" % (c.get("kcmc"), c.get("cdmc"),
                                              c.get("xm"), c.get("zcd")))
        if xsxx:
            print("  学生/学期字段：%s" % ", ".join(sorted(xsxx.keys()))[:400])
    return obj


def fetch_exam(xnm="", xqm=""):
    if not xnm:
        xnm, xqm = cur_term()
    print("[3/5] 考试安排  xnm=%s xqm=%s" % (xnm or "(当前)", xqm or "(当前)"))
    obj = try_json("exam_%s_%s" % (xnm or "cur", xqm or "cur"),
                   CTX + "/kwgl/kscx_cxXsksxxIndex.html?doType=query&gnmkdm=N358105",
                   {"xnm": xnm, "xqm": xqm, "ksmcdmb_id": "", "kc": "", "ksrq": "",
                    "kkbm_id": "", "_search": "false",
                    "nd": int(time.time() * 1000),
                    "queryModel.showCount": "100", "queryModel.currentPage": "1",
                    "queryModel.sortName": "", "queryModel.sortOrder": "asc"})
    if isinstance(obj, dict):
        items = obj.get("items") or []
        print("  考试条数：%d" % len(items))
        if items:
            print("  字段样例：%s" % ", ".join(sorted(items[0].keys())))
            it = items[0]
            print("  例：%s | %s | %s %s" % (it.get("kcmc"), it.get("cdmc"),
                                           it.get("kssj"), it.get("kssj")))
    return obj


def fetch_grades(years=(2026, 2025, 2024)):
    print("[4/5] 成绩（遍历学期）")
    found = 0
    for y in years:
        for q in (3, 12, 16):
            # 注意：/cjcx/cjcx_cxXsgrcj.html 在 HAUT 是 404「系统维护页面」，
            # 能用的是成绩总览页的 jqGrid 数据接口（doType=query）
            obj = try_json("grade_%s_%s" % (y, q),
                           CTX + "/cjcx/cjcx_cxDgXscj.html?doType=query&gnmkdm=N305005",
                           {"xnm": y, "xqm": q, "_search": "false",
                            "nd": int(time.time() * 1000),
                            "queryModel.showCount": "200", "queryModel.currentPage": "1",
                            "queryModel.sortName": "", "queryModel.sortOrder": "asc",
                            "sfzcjx": "0"})
            if isinstance(obj, dict):
                items = obj.get("items") or []
                if items:
                    found += len(items)
                    print("    %s-%s：%d 条  例：%s %s" % (
                        y, q, len(items), items[0].get("kcmc"), items[0].get("cj")))
                    if found == len(items):
                        print("    字段样例：%s" % ", ".join(sorted(items[0].keys())))
    if not found:
        print("  未取到成绩，可能学期参数不同（需看 grade_*.html 报错）")


def fetch_weekinfo():
    print("[5/5] 当前教学周 / 校历")
    obj = try_json("week_info",
                   CTX + "/kbcx/xskbcx_cxXsKb.html?gnmkdm=N2151",
                   {"xnm": "", "xqm": "", "kzlx": "ck"})
    if isinstance(obj, dict) and obj.get("xsxx"):
        xs = obj["xsxx"]
        print("  XQJSSJ1(学期结束)/DQZ(当前周) 等字段：%s" % {
            k: v for k, v in xs.items() if k in ("DQZ", "XQJSSJ1", "XQKSSJ1", "XM", "XH", "NJDM")})


# ------------------------------------------------------------------ main
def main():
    if len(sys.argv) >= 3:
        user, pwd = sys.argv[1], sys.argv[2]
    else:
        import getpass
        user = input("学号: ").strip()
        pwd = getpass.getpass("密码（不回显）: ")

    os.makedirs(OUT_DIR, exist_ok=True)
    print("== 登录 %s ==" % BASE)
    global SESSION, SESSION_LAST_MENU
    SESSION = Session()
    SESSION_LAST_MENU = login(SESSION, user, pwd)
    dump("menu.html", SESSION_LAST_MENU)
    print("== 抓取数据 ==")
    fetch_student_info()
    fetch_schedule()
    fetch_exam()
    fetch_grades()
    fetch_weekinfo()
    print("\n完成。所有原始返回已存到：%s" % OUT_DIR)
    print("把这个目录打包发给我即可（里面不含密码）。")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print("\n[失败] %s" % e)
        sys.exit(1)
