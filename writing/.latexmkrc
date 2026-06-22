# Fail fast instead of spinning through thousands of nonstopmode recoveries.
$pdflatex = 'pdflatex -halt-on-error -file-line-error %O %S';
