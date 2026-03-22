# Keep bibliography and asset resolution stable when latexmk is launched
# directly from the writing/ directory.
$ENV{'PAR_GLOBAL_TEMP'} = '/tmp/gmt-thesis-biber-cache';
$do_cd = 1;
$pdf_mode = 1;
$bibtex_use = 2;
$biber = 'biber %O %B';
