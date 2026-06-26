// lib/src/utils/car_reader.dart

/// Re-export of the standard CAR v1/v2 API from
/// [package:dart_ipfs/src/core/data_structures/car.dart].
///
/// The previous transitional [CarReader] wrapper that delegated to the legacy
/// protobuf-based [CAR] class has been removed in favor of the standard
/// streaming API defined in `doc/specs/features/CAR_FORMAT_SPEC.md`.
library;

export 'package:dart_ipfs/src/core/data_structures/car.dart'
    show
        CarException,
        CarHeaderException,
        CarSectionException,
        CarV2Exception,
        CarIndexException,
        CarHeader,
        CarSection,
        CarReader,
        IndexBuilder;
