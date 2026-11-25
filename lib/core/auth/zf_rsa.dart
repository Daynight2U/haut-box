import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// 正方教务的密码加密：RSA/ECB/PKCS1Padding，公钥以 base64 的 modulus / exponent 下发。
///
/// 前端原本是 jsbn（`rsaKey.setPublic(b64tohex(modulus), b64tohex(exponent))` +
/// `hex2b64(rsaKey.encrypt(pwd))`），这里用 BigInt.modPow 等价实现，
/// 不引入任何三方库。
class ZfRsa {
  ZfRsa({required String modulusB64, required String exponentB64})
      : _n = _bytesToBigInt(base64Decode(modulusB64)),
        _e = _bytesToBigInt(base64Decode(exponentB64)) {
        _k = (_n.bitLength + 7) >> 3;
      }

  final BigInt _n;
  final BigInt _e;
  late final int _k;

  static BigInt _bytesToBigInt(List<int> bytes) {
    var v = BigInt.zero;
    for (final b in bytes) {
      v = (v << 8) | BigInt.from(b);
    }
    return v;
  }

  static Uint8List _bigIntToBytes(BigInt v, int len) {
    final out = Uint8List(len);
    var x = v;
    final mask = BigInt.from(0xff);
    for (var i = len - 1; i >= 0; i--) {
      out[i] = (x & mask).toInt();
      x = x >> 8;
    }
    return out;
  }

  /// 返回 base64 密文
  String encrypt(String plain) {
    final msg = utf8.encode(plain);
    if (msg.length > _k - 11) {
      throw ArgumentError('密码过长，超出口令上限');
    }
    final ps = <int>[];
    final rnd = Random.secure();
    while (ps.length < _k - msg.length - 3) {
      final b = rnd.nextInt(256);
      if (b != 0) ps.add(b);
    }
    // 0x00 || 0x02 || PS || 0x00 || M，长度必须正好 _k
    final block = Uint8List(_k)
      ..[0] = 0x00
      ..[1] = 0x02;
    var off = 2;
    for (final b in ps) {
      block[off++] = b;
    }
    block[off++] = 0x00;
    for (final b in msg) {
      block[off++] = b;
    }
    final m = _bytesToBigInt(block);
    final c = m.modPow(_e, _n);
    return base64Encode(_bigIntToBytes(c, _k));
  }
}
