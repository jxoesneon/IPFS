// lib/src/utils/car_reader.dart

/// Re-export of the standard CAR v1/v2 API from the core data structures.
///
/// The previous transitional [CarReader] wrapper that delegated to the legacy
/// protobuf-based [CAR] class has been removed in favor of the standard
/// streaming API defined in `doc/specs/features/CAR_FORMAT_SPEC.md`.
library;

export '../core/data_structures/car.dart'
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
