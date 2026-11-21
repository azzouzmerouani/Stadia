/// Payment abstraction. The app only ever talks to [PaymentService]; the mock
/// is wired today and [ChargilyPaymentService] is the production slot.
library;

enum PaymentMethod {
  cib('CIB', 'Interbank card'),
  edahabia('Edahabia', 'Algérie Poste card');

  const PaymentMethod(this.label, this.caption);

  final String label;
  final String caption;

  /// Value Chargily Pay expects in `payment_method`.
  String get chargilyValue => name;
}

class PaymentRequest {
  const PaymentRequest({
    required this.orderId,
    required this.amount,
    required this.method,
    required this.description,
  });

  final String orderId;

  /// Amount in DZD (whole dinars).
  final int amount;
  final PaymentMethod method;
  final String description;
}

class PaymentReceipt {
  const PaymentReceipt({
    required this.reference,
    required this.amount,
    required this.method,
    required this.paidAt,
  });

  final String reference;
  final int amount;
  final PaymentMethod method;
  final DateTime paidAt;
}

sealed class PaymentResult {
  const PaymentResult();
}

class PaymentSucceeded extends PaymentResult {
  const PaymentSucceeded(this.receipt);
  final PaymentReceipt receipt;
}

class PaymentFailed extends PaymentResult {
  const PaymentFailed(this.message);
  final String message;
}

class PaymentCancelled extends PaymentResult {
  const PaymentCancelled();
}

abstract interface class PaymentService {
  Future<PaymentResult> pay(PaymentRequest request);
}

/// Always succeeds after a short delay. Used until Chargily is wired.
class MockPaymentService implements PaymentService {
  MockPaymentService({this.delay = const Duration(milliseconds: 1400)});

  final Duration delay;

  @override
  Future<PaymentResult> pay(PaymentRequest request) async {
    await Future<void>.delayed(delay);
    final stamp = DateTime.now();
    final suffix =
        stamp.millisecondsSinceEpoch.toRadixString(36).toUpperCase();
    return PaymentSucceeded(
      PaymentReceipt(
        reference: 'MOCK-${request.method.name.toUpperCase()}-$suffix',
        amount: request.amount,
        method: request.method,
        paidAt: stamp,
      ),
    );
  }
}

/// Production slot for Chargily Pay (CIB / Edahabia).
///
/// Chargily's secret key must never ship in the app. Intended flow:
/// 1. The app asks *your backend* to create a checkout for [PaymentRequest].
/// 2. The backend calls Chargily Pay `POST /checkouts` (amount, currency
///    `dzd`, `payment_method`, `success_url`, `failure_url`,
///    `webhook_endpoint`, `metadata.orderId`) and returns `checkout_url`.
/// 3. The app opens `checkout_url` in an in-app browser and waits.
/// 4. Chargily calls the backend webhook; the backend verifies the
///    `signature` header (HMAC-SHA256 of the raw body with the secret key),
///    marks the order paid and issues the ticket; the app polls or listens.
class ChargilyPaymentService implements PaymentService {
  ChargilyPaymentService({required this.backendBaseUrl});

  final Uri backendBaseUrl;

  @override
  Future<PaymentResult> pay(PaymentRequest request) {
    throw UnimplementedError(
      'Chargily checkout needs a backend endpoint at $backendBaseUrl '
      '(see README, "Going to production").',
    );
  }
}
