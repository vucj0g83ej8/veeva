import 'admin_voucher_importer_base.dart';

AdminVoucherImporter createAdminVoucherImporter() {
  return _StubAdminVoucherImporter();
}

class _StubAdminVoucherImporter implements AdminVoucherImporter {
  @override
  Future<ImportedVoucherLinks?> pickVoucherLinks() async {
    return null;
  }
}
