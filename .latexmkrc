# Build from the document directory so relative bibliography and asset paths
# resolve the same way whether latexmk is launched from the repo root or a
# subdirectory such as writing/.
$do_cd = 1;
$pdf_mode = 1;
$bibtex_use = 2;
$biber = 'biber %O %B';
