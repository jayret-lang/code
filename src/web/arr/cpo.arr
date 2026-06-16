provide *
import ast as A
import either as E
import load-lib as L
import string-dict as SD
import file("../../../pyret/src/arr/compiler/compile-structs.arr") as CS
import file("../../../pyret/src/arr/compiler/compile-lib.arr") as CL
import file("../../../pyret/src/arr/compiler/repl.arr") as R
import file("../../../pyret/src/arr/compiler/js-of-pyret.arr") as JSP
import file("../../../pyret/src/arr/compiler/ast-util.arr") as AU

# Mirrors the image exports in starter2024.arr so DCIC-style intro
# programs (triangle, circle, overlay, ...) work in the playground
# without an explicit `import image as I`. Scoped to user-written
# programs only — adding these to CS.standard-imports would shadow
# names like `line` in compiler internals (js-ast.arr).
playground-extra-imports = CS.extra-imports(
  CS.standard-imports.imports +
  [list:
    CS.extra-import(CS.builtin("image"), "image", [list:
        "above", "above-align", "above-align-list", "above-list",
        "add-line", "below", "below-align", "below-align-list",
        "below-list", "beside", "beside-align", "beside-align-list",
        "beside-list", "center-pinhole", "circle", "color-at-position",
        "color-list-to-bitmap", "color-list-to-image", "color-named",
        "crop", "draw-pinhole", "ellipse", "empty-color-scene",
        "empty-image", "empty-scene", "ff-decorative", "ff-default",
        "ff-modern", "ff-roman", "ff-script", "ff-swiss", "ff-symbol",
        "ff-system", "flip-horizontal", "flip-vertical", "frame",
        "fs-italic", "fs-normal", "fs-slant", "fw-bold", "fw-light",
        "fw-normal", "image-baseline", "image-height", "image-pinhole-x",
        "image-pinhole-y", "image-to-color-list", "image-url",
        "image-width", "images-difference", "images-equal", "is-angle",
        "is-image", "is-image-color", "is-mode-fade", "is-mode-outline",
        "is-mode-solid", "isosceles-triangle", "line", "mode-fade",
        "mode-outline", "mode-solid", "move-pinhole", "name-to-color",
        "overlay", "overlay-align", "overlay-align-list", "overlay-list",
        "overlay-onto-offset", "overlay-xy", "place-image",
        "place-image-align", "place-pinhole", "point", "point-polar",
        "point-polygon", "point-xy", "put-image", "radial-star",
        "rectangle", "regular-polygon", "rhombus", "right-triangle",
        "rotate", "scale", "scale-xy", "scene-line", "square", "star",
        "star-polygon", "star-sized", "text", "text-font", "triangle",
        "triangle-aas", "triangle-asa", "triangle-ass", "triangle-saa",
        "triangle-sas", "triangle-ssa", "triangle-sss", "underlay",
        "underlay-align", "underlay-align-list", "underlay-list",
        "underlay-xy", "wedge", "x-center", "x-left", "x-middle",
        "x-pinhole", "x-right", "y-baseline", "y-bottom", "y-center",
        "y-middle", "y-pinhole", "y-top"
      ],
      [list:
        "FillMode", "FontFamily", "FontStyle", "FontWeight", "Image",
        "Point", "XPlace", "YPlace"
      ])
  ])

fun make-dep(raw-dep):
 if raw-dep.import-type == "builtin":
    CS.builtin(raw-dep.name)
  else:
    CS.dependency(raw-dep.protocol, raw-array-to-list(raw-dep.args))
  end
end

fun get-builtin-loadable(raw, uri) -> CL.Loadable:
  provs = CS.provides-from-raw-provides(uri, {
    uri: uri,
    values: raw-array-to-list(raw.get-raw-value-provides()),
    aliases: raw-array-to-list(raw.get-raw-alias-provides()),
    datatypes: raw-array-to-list(raw.get-raw-datatype-provides()),
    modules: raw-array-to-list(raw.get-raw-module-provides())
  })
  CL.module-as-string(
      AU.canonicalize-provides(provs, CS.no-builtins),
      CS.no-builtins,
      CS.computed-none,
      CS.ok(JSP.ccp-string(raw.get-raw-compiled())))
end

fun get-builtin-modules(builtin-mods) block:
  modules = [SD.mutable-string-dict: ]
  for each(b from builtin-mods):
    modules.set-now(b.uri, get-builtin-loadable(b.raw, b.uri))
  end
  modules
end

fun make-js-locator-from-raw(raw, check-mode, uri, name):
  {
    method needs-compile(_, _): false end,
    method get-modified-time(self):
      0
    end,
    method get-options(self, options):
      options.{ check-mode: check-mode }
    end,
    method get-module(_):
      raise("Should never fetch source for raw JS module " + name)
    end,
    method get-extra-imports(self):
      CS.standard-imports
    end,
    method get-dependencies(_):
      deps = raw.get-raw-dependencies()
      raw-array-to-list(deps).map(make-dep)
    end,
    method get-native-modules(_):
      natives = raw.get-raw-native-modules()
      raw-array-to-list(natives).map(CS.requirejs)
    end,
    method get-globals(_):
      CS.standard-globals
    end,

    method uri(_): uri end,
    method name(_): name end,

    method set-compiled(_, _, _): nothing end,
    method get-compiled(self):
      provs = CS.provides-from-raw-provides(self.uri(), {
        uri: self.uri(),
        values: raw-array-to-list(raw.get-raw-value-provides()),
        aliases: raw-array-to-list(raw.get-raw-alias-provides()),
        datatypes: raw-array-to-list(raw.get-raw-datatype-provides()),
        modules: raw-array-to-list(raw.get-raw-module-provides())
      })
      some(CL.module-as-string(provs, CS.no-builtins, CS.computed-none, CS.ok(JSP.ccp-string(raw.get-raw-compiled()))))
    end,

    method _equals(self, other, req-eq):
      req-eq(self.uri(), other.uri())
    end
  }
end

fun make-builtin-js-locator(builtin-name, raw):
  make-js-locator-from-raw(raw, false, "builtin://" + builtin-name, builtin-name)
end

fun ast-locator(uri :: String, a :: A.Program):
  {
    method needs-compile(self, _): true end,
    method get-modified-time(self): 0 end,
    method get-options(self, options): options end,
    method get-module(self): CL.pyret-ast(a) end,
    method get-native-modules(self): [list:] end,
    method get-dependencies(self):
      CL.get-dependencies(self.get-module(), uri) +
      playground-extra-imports.imports.map(_.dependency)
    end,
    method get-extra-imports(self): playground-extra-imports end,
    method get-globals(self): CS.standard-globals end,
    method uri(self): uri end,
    method name(self): uri end,
    method set-compiled(self, _, _): nothing end,
    method get-compiled(self): none end,
    method _equals(self, other, rec-eq): rec-eq(other.uri(), self.uri()) end
  }
end

save-protocols = [list: "my-gdrive", "shared-gdrive"]

fun make-on-compile(save-gdrive-file):
  on-compile = lam(locator, loadable, trace) block:
    locator.set-compiled(loadable, SD.make-mutable-string-dict())
    locuri = loadable.provides.from-uri
    cases(CS.CompileResult) loadable.result-printer:
      | ok(ccp) =>
        protocol = string-substring(locuri, 0, string-index-of(locuri, "://"))
        ask block:
          | save-protocols.member(protocol) then:
            save-gdrive-file(locuri, ccp.pyret-to-js-runnable())
            nothing
          # We don't save copies of other kinds of modules, which are already
          # in pure JS.
          | otherwise: nothing
        end

      # If the compilation errored, there's nothing meaningful to save, as the
      # module will have to be recompiled for the program to work anyway
      | err(_) => nothing
    end
    # NOTE(joe): The CLI module loader does an extra step of using
    # ccp-file here to avoid keeping compiled strings in memory
    # when not strictly necessary, to reduce overall footprint.
    # There's an opportunity to do this here by using localStorage,
    # which is probably best implemented with something like ccp-thunk,
    # which could easily abstract over many ways of getting a compiled string
    loadable
  end
  on-compile
end

fun compile-ast(ast, runtime, finder, options) -> E.Either:
  uri = ast.l.source
  locator = ast-locator(uri, ast)
  wl = CL.compile-worklist(finder, locator, {})
  cases(E.Either) CL.compile-standalone(wl, SD.make-mutable-string-dict(), options):
    | left(problems) => E.left(problems)
    | right(standalone) => E.right(standalone.js-ast.to-ugly-source())
  end
end

fun run(runtime, realm, js-source):
  L.run-program(runtime, realm, js-source, {check-all: false})
end

fun make-repl(builtin-mods, runtime, realm, finder):
  modules = get-builtin-modules(builtin-mods)
  repl = R.make-repl(runtime, modules, realm, "cpo-context-currently-unused", finder)
  repl
end
