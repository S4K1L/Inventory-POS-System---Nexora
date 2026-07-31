/// Feature-flag keys for the Inventory module. These are the sub-features a
/// company can have individually locked/unlocked (stored in
/// `companies/{id}.features`).
class InventoryFeatures {
  InventoryFeatures._();

  static const barcode = 'inventory.barcode';
  static const qr = 'inventory.qr';
  static const wholesale = 'inventory.wholesale';
  static const batchExpiry = 'inventory.batch_expiry';
  static const multiWarehouse = 'inventory.multi_warehouse';
}
