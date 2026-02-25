cmake_minimum_required(VERSION 3.18.1)
project("rnnoise" C)

# ─── Paths ───────────────────────────────────────────────────────────────────
set(RNNOISE_SRC     ${CMAKE_CURRENT_SOURCE_DIR}/rnnoise/src)
set(RNNOISE_INCLUDE ${CMAKE_CURRENT_SOURCE_DIR}/rnnoise/include)

# ─── Guard: fail clearly if source isn't present ─────────────────────────────
if(NOT EXISTS "${RNNOISE_SRC}/denoise.c")
    message(FATAL_ERROR
        "\n"
        "RNNoise source not found at ${RNNOISE_SRC}\n"
        "\n"
        "Run the setup script first, then rebuild:\n"
        "  Windows:  scripts\\setup_rnnoise.ps1\n"
        "  Linux/Mac: scripts/setup_rnnoise.sh\n"
        "\n"
        "Then: flutter build apk --release\n")
endif()

if(NOT EXISTS "${RNNOISE_SRC}/rnnoise_data.c")
    message(FATAL_ERROR
        "\n"
        "RNNoise model weights not found at ${RNNOISE_SRC}/rnnoise_data.c\n"
        "\n"
        "Run the model download script from the rnnoise directory:\n"
        "  bash android/app/src/main/cpp/rnnoise/download_model.sh\n"
        "\n"
        "Then: flutter build apk --release\n")
endif()

# ─── Source files (from rnnoise/Makefile.am RNNOISE_SOURCES) ─────────────────
# X86-specific SIMD sources (SSE4.1, AVX2) are intentionally excluded —
# not needed for ARM Android targets.
set(RNNOISE_SOURCES
    ${RNNOISE_SRC}/denoise.c
    ${RNNOISE_SRC}/rnn.c
    ${RNNOISE_SRC}/pitch.c
    ${RNNOISE_SRC}/kiss_fft.c
    ${RNNOISE_SRC}/celt_lpc.c
    ${RNNOISE_SRC}/nnet.c
    ${RNNOISE_SRC}/nnet_default.c
    ${RNNOISE_SRC}/parse_lpcnet_weights.c
    ${RNNOISE_SRC}/rnnoise_data.c
    ${RNNOISE_SRC}/rnnoise_tables.c
)

# ─── Build shared library ─────────────────────────────────────────────────────
add_library(rnnoise SHARED ${RNNOISE_SOURCES})

target_include_directories(rnnoise PRIVATE
    ${RNNOISE_SRC}       # internal headers (arch.h, pitch.h, nnet.h, etc.)
    ${RNNOISE_INCLUDE}   # public API (rnnoise.h)
)

target_compile_definitions(rnnoise PRIVATE
    RNNOISE_BUILD   # required: makes RNNOISE_EXPORT emit __attribute__((visibility("default")))
                    # so rnnoise_create/destroy/process_frame are exported from the .so
)

target_compile_options(rnnoise PRIVATE
    -O2
    -fno-exceptions
    -fvisibility=hidden   # hide internal symbols; RNNOISE_BUILD overrides for public API
    # -ffast-math is intentionally omitted: rnnoise/src/arch.h rejects it
    # unless FLOAT_APPROX is defined, which risks incorrect output on NaN input.
)

set_target_properties(rnnoise PROPERTIES
    C_VISIBILITY_PRESET hidden
)

message(STATUS "RNNoise: building librnnoise.so from ${RNNOISE_SRC}")
