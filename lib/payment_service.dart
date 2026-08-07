import 'package:flutter/material.dart';

/// PaymentService
///
/// Abstracted payment gateway for Jesture premium level unlock.
/// Currently configured as a "Coming Soon" placeholder.
///
/// ─── RAZORPAY INTEGRATION GUIDE ───────────────────────────────────────────────
/// When you receive your credentials from your boss, follow these steps:
///
/// Step 1: Uncomment the razorpay_flutter import below.
/// Step 2: Replace _RAZORPAY_KEY_ID with your actual Razorpay Test/Live Key ID.
/// Step 3: Set _UNLOCK_AMOUNT_PAISE to your price in paise (₹49 = 4900).
/// Step 4: Uncomment and complete the _initRazorpay() and _handlePayment* methods.
/// Step 5: Change _isRazorpayActive = true.
/// ──────────────────────────────────────────────────────────────────────────────

// import 'package:razorpay_flutter/razorpay_flutter.dart';  // ← Uncomment when ready

enum PaymentStatus { success, failed, comingSoon, cancelled }

class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  // ─── RAZORPAY CONFIG (fill when credentials arrive) ──────────────────────────
  static const bool isRazorpayActive = false;
  static const String razorpayKeyId = 'YOUR_RAZORPAY_KEY_ID_HERE';
  static const int unlockAmountPaise = 4900; // ₹49 = 4900 paise
  static const String unlockCurrency = 'INR';
  static const String unlockDescription = 'Jesture — Level 3 Unlock';
  // ─────────────────────────────────────────────────────────────────────────────

  // Razorpay? _razorpay;  // ← Uncomment when ready

  /// Call this from the Paywall screen when user taps "Unlock Premium"
  Future<PaymentStatus> initiateUnlock(BuildContext context) async {
    if (!isRazorpayActive) {
      // Show a polished "Coming Soon" bottom sheet (Play Store compliant)
      await _showComingSoonSheet(context);
      return PaymentStatus.comingSoon;
    }

    // ─── RAZORPAY ACTIVE PATH (uncomment block below when credentials arrive) ─
    // _razorpay = Razorpay();
    // _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    // _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    // _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    //
    // var options = {
    //   'key': _RAZORPAY_KEY_ID,
    //   'amount': _UNLOCK_AMOUNT_PAISE,
    //   'currency': _UNLOCK_CURRENCY,
    //   'name': 'Jesture',
    //   'description': _UNLOCK_DESCRIPTION,
    //   'prefill': {'contact': '', 'email': ''},
    //   'external': {'wallets': ['paytm', 'phonepe', 'googlepay']}
    // };
    // _razorpay!.open(options);
    // ─────────────────────────────────────────────────────────────────────────

    return PaymentStatus.comingSoon;
  }

  // void _handlePaymentSuccess(PaymentSuccessResponse response) {
  //   // TODO: Unlock Level 3 in SharedPreferences and navigate
  // }

  // void _handlePaymentError(PaymentFailureResponse response) {
  //   // Handle error
  // }

  // void _handleExternalWallet(ExternalWalletResponse response) {
  //   // Handle wallet selection
  // }

  Future<void> _showComingSoonSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(32, 20, 32, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 4)],
              ),
              child: const Icon(Icons.rocket_launch_rounded, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 24),
            const Text(
              '🚀 Premium is Coming Soon!',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            const Text(
              'We are setting up our payment system to make unlocking smooth and safe for you.\n\nStay tuned — premium levels will be available very soon!',
              style: TextStyle(color: Colors.white60, fontSize: 15, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amberAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Got it!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void dispose() {
    // _razorpay?.clear();  // ← Uncomment when Razorpay is active
  }
}
