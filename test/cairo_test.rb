require "test_utils"

run_test(
  library_name:  "Cairo",
  ffi_lib:       "cairo",
  cflags:        ["-Itest/headers/cairo", "-Itest/headers/freetype2", "-Itest/headers/glib-2.0"],
  prefixes:      ["cairo_", "_cairo_", "CAIRO_"],
  file_mappings: {
    "cairo-deprecated.h"         => "deprecated.rb",
    "cairo-features.h"           => "features.rb",
    "cairo-ft.h"                 => "ft.rb",
    # "cairo-gobject.h"            => "gobject.rb",
    "cairo.h"                    => "core.rb",
    "cairo-pdf.h"                => "pdf.rb",
    "cairo-ps.h"                 => "ps.rb",
    # "cairo-script-interpreter.h" => "script_interpreter.rb",
    "cairo-svg.h"                => "svg.rb",
    "cairo-version.h"            => "version.rb",
    "cairo-xcb.h"                => "xcb.rb",
    "cairo-xlib.h"               => "xlib.rb",
    "cairo-xlib-xrender.h"       => "xlib_xrender.rb"
  }
)
