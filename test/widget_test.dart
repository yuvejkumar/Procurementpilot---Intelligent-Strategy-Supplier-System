import 'package:flutter_test/flutter_test.dart';
import 'package:procurement_pilot/main.dart';

void main() {
  group('Supplier Model Tests', () {
    test('Supplier serialization and deserialization preserves properties', () {
      final supplier = Supplier(
        id: 'sup-001',
        name: 'Apex Fasteners Ltd',
        category: 'Hardware',
        price: 120.5,
        deliveryDays: 4,
        capacity: 5000,
        minOrder: 200,
        reliability: 0.94,
        qualityScore: 0.92,
        priceRisk: 0.15,
        deliveryRisk: 0.10,
        qualityRisk: 0.08,
        capacityRisk: 0.20,
        currentStock: 1200,
        location: 'Bengaluru, IN',
      );

      final json = supplier.toJson();
      final restored = Supplier.fromJson('sup-001', json);

      expect(restored.id, equals('sup-001'));
      expect(restored.name, equals('Apex Fasteners Ltd'));
      expect(restored.category, equals('Hardware'));
      expect(restored.price, equals(120.5));
      expect(restored.deliveryDays, equals(4));
      expect(restored.capacity, equals(5000));
      expect(restored.reliability, closeTo(0.94, 0.001));
    });

    test('Supplier default values apply when optional json keys are missing', () {
      final supplier = Supplier.fromJson('sup-fallback', {});

      expect(supplier.id, equals('sup-fallback'));
      expect(supplier.name, equals('Unknown'));
      expect(supplier.category, equals('General'));
      expect(supplier.deliveryDays, equals(5));
      expect(supplier.reliability, closeTo(0.85, 0.001));
    });
  });

  group('RandomForestMLBackend Deterministic Calculations', () {
    final supplier = Supplier(
      id: 'sup-002',
      name: 'Global Chip Corp',
      category: 'Electronics',
      price: 250.0,
      deliveryDays: 10,
      capacity: 10000,
      minOrder: 500,
      reliability: 0.95,
      qualityScore: 0.90,
      priceRisk: 0.15,
      deliveryRisk: 0.10,
      qualityRisk: 0.12,
      capacityRisk: 0.18,
      currentStock: 2500,
      location: 'Pune, IN',
    );

    test('predictOverallRisk clamps within 5.0 and 98.0 boundaries', () {
      final baseRisk = RandomForestMLBackend.predictOverallRisk(supplier);
      expect(baseRisk, greaterThanOrEqualTo(5.0));
      expect(baseRisk, lessThanOrEqualTo(98.0));

      final disruptedRisk = RandomForestMLBackend.predictOverallRisk(
        supplier,
        disruptionSeverity: 100.0,
      );
      expect(disruptedRisk, greaterThanOrEqualTo(5.0));
      expect(disruptedRisk, lessThanOrEqualTo(98.0));
      expect(disruptedRisk, greaterThan(baseRisk));
    });

    test('predictUnitPrice applies bulk discount and disruption penalty', () {
      final standardPrice = RandomForestMLBackend.predictUnitPrice(supplier, orderQty: 1000);
      expect(standardPrice, equals(250.0));

      final bulkPrice = RandomForestMLBackend.predictUnitPrice(supplier, orderQty: 5000);
      expect(bulkPrice, closeTo(250.0 * 0.95, 0.01));

      final disruptedPrice = RandomForestMLBackend.predictUnitPrice(
        supplier,
        orderQty: 1000,
        disruptionSeverity: 50.0,
      );
      expect(disruptedPrice, greaterThan(standardPrice));
    });

    test('predictDeliveryDays reflects supplier reliability and disruption', () {
      final normalDays = RandomForestMLBackend.predictDeliveryDays(supplier);
      expect(normalDays, greaterThanOrEqualTo(supplier.deliveryDays));

      final delayedDays = RandomForestMLBackend.predictDeliveryDays(
        supplier,
        disruptionSeverity: 75.0,
      );
      expect(delayedDays, greaterThanOrEqualTo(normalDays));
    });
  });
}
