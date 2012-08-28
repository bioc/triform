(TeX-add-style-hook "triform"
 (lambda ()
    (LaTeX-add-bibliographies)
    (TeX-add-symbols
     "scscst"
     "scst")
    (TeX-run-style-hooks
     "inputenc"
     "utf8"
     "natbib"
     "authoryear"
     "round"
     "pdfcolmk"
     "color"
     "url"
     "hyperref"
     "latex2e"
     "art11"
     "article"
     "11pt")))

