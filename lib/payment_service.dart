class PaymentService {
  // Stub for document fee payments. Integrate gateway here (Stripe, bKash, SSLCOMMERZ, etc.)
  static Future<bool> payDocFee({
    required String tenderId,
    required int amount,
  }) async {
    await Future.delayed(const Duration(seconds: 2));
    return true;
  }
}
