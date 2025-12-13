# Mock Refinement Notes

## Files Needing Interface Refinement

The following mock files were created in Phase 1 but need interface corrections before use:

### 1. mock_security_manager.dart (`test/mocks/`)
**Status**: 🔨 Needs Refinement

**Issues**:
- Uses `PrivateKey` instead of `IPFSPrivateKey`
- Constructor doesn't match `SecurityManager` signature (needs `SecurityConfig`, `MetricsCollector`)
- `@override` annotations don't match parent class methods

**Impact**: Not currently used in passing tests (MockDHTHandler is sufficient for Phase 2A)

**Future Work**: When IPNS testing requires security manager:
1. Update to use `IPFSPrivateKey` from `package:dart_ipfs/src/utils/private_key.dart`
2. Add proper constructor with `SecurityConfig` and `MetricsCollector`
3. Remove invalid `@override` annotations or match actual SecurityManager interface

---

### 2. mock_block_store.dart (`test/mocks/`)
**Status**: 🔨 Needs Refinement

**Issues**:
- Trying to implement `IBlockStore` which may not be a proper interface
- `@override` annotations don't match parent

**Impact**: Not currently used in passing tests (InMemoryDatastore is sufficient)

**Future Work**: When block store testing is needed:
1. Verify `IBlockStore` interface exists and is current
2. Match actual interface methods
3. Remove invalid `@override` annotations

---

## Decision

**These are NOT required for current Phase 1 & 2A success:**
- ✅ 14 integration tests passing (use InMemoryDatastore + MockDHTHandler)
- ✅ 11 validation tests passing  
- ✅ 11 datastore tests passing

**Defer refinement to Phase 3 or when specifically needed for:**
- IPNS integration testing (SecurityManager)
- Complex block storage scenarios (BlockStore)

---

*Note: These files were created as part of comprehensive mock infrastructure but aren't blocking current testing success.*
