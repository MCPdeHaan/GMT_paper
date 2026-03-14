# LaTeX Compilation Troubleshooting Guide
*GMT Thesis — Utrecht University School of Economics*

---

## What went wrong with `cbcr_data_annex.tex` (10 March 2026)

Two TinyTeX packages were missing after a system update:

| Package | Error message | Fix |
|---|---|---|
| `parskip` | `File 'parskip.sty' not found` | `tlmgr install parskip` |
| `babel-english` | `Package babel Error: Unknown option 'british'` | `tlmgr install babel-english` |

After installing, the TeX filename database also had to be refreshed:
```
sudo mktexlsr
```

Root cause: TinyTeX's remote repository moved to 2026 while the local installation was 2025. `tlmgr install` silently appeared to succeed but the ls-R database was not updated with normal user permissions, so pdflatex still could not find the files.

---

## Common causes of LaTeX compilation failures

### 1. Missing package (`File 'xxx.sty' not found`)
**Cause:** The package is not installed in TinyTeX.  
**Fix:**
```bash
tlmgr install <package-name>
sudo mktexlsr          # always run this after installing
```
**Prevention:** When you add a new `\usepackage{...}` line to any document, immediately run a test compile and install the package if missing.

### 2. Missing language definition (`Package babel Error: Unknown option 'xxx'`)
**Cause:** The babel language file is in a separate package (e.g. `british` is in `babel-english`).  
**Fix:**
```bash
tlmgr install babel-english   # for english/british/american
sudo mktexlsr
```

### 3. `tlmgr` version mismatch (`Local TeX Live (20xx) is older than remote repository (20xx+1)`)
**Cause:** TinyTeX installs a specific TeX Live year; when a new year is released the default CTAN mirror switches.  
**Fix:** Point tlmgr to the matching historic mirror:
```bash
tlmgr option repository https://ftp.tu-chemnitz.de/pub/tug/historic/systems/texlive/2025/tlnet-final/
```
Then install as normal. Replace `2025` with the year shown in your TinyTeX installation (`tlmgr --version`).

### 4. `Undefined control sequence` cascade after an earlier error
**Cause:** A single unrecognised package or command causes babel/biblatex/hyperref to fail to load, producing dozens of secondary errors that obscure the first one.  
**Fix:** Always look at the **first** error in the log, not the last. Run:
```bash
grep "^!" cbcr_data_annex.log | head -5
```

### 5. Stale `.aux`/`.fdb_latexmk` cache after a failed compile
**Cause:** latexmk caches the failed state and refuses to rerun.  
**Fix:**
```bash
latexmk -C <document>.tex   # removes all generated files
latexmk -pdf -interaction=nonstopmode <document>.tex
```

### 6. `biber` vs `bibtex` mismatch
**Cause:** The preamble uses `backend=biber` but the system tries to run bibtex (or vice versa), corrupting the `.bbl` file.  
**Fix:** All thesis documents use `backend=biber`. Never mix. If the bibliography looks broken, run:
```bash
latexmk -C <document>.tex
latexmk -pdf -interaction=nonstopmode <document>.tex
```

### 7. Landscape tables crashing (package `pdflscape` missing)
**Cause:** `pdflscape` is not part of the base LaTeX install.  
**Fix:**
```bash
tlmgr install pdflscape
sudo mktexlsr
```

---

## Standard preamble — use `GMT_thesis_overview.tex` as template

Every new document should start from the following preamble (core packages only — add table/figure packages as needed):

```latex
\documentclass[11pt,a4paper]{article}

% Fonts
\usepackage[utf8]{inputenc}
\usepackage[T1]{fontenc}
\usepackage{textcomp}
\usepackage{lmodern}

% Layout
\usepackage[margin=2.5cm]{geometry}
\usepackage{setspace}
\usepackage{parskip}
\onehalfspacing

% Language
\usepackage[british]{babel}

% Bibliography (APA 7th edition)
\usepackage{csquotes}
\usepackage[backend=biber,style=apa,sorting=nyt,natbib=true]{biblatex}
\DeclareLanguageMapping{british}{british-apa}
\addbibresource{bibliography.bib}

% Mathematics
\usepackage{amsmath,amssymb}

% Tables and figures (add only what you need)
\usepackage{booktabs}
\usepackage{longtable}
\usepackage{graphicx}
\usepackage{float}
% \usepackage{array}       % advanced column types
% \usepackage{multirow}    % spanning rows in tables
% \usepackage{tabularx}    % auto-width columns
% \usepackage{pdflscape}   % landscape pages

% Hyperlinks
\usepackage{xcolor}
\usepackage[colorlinks=true,linkcolor=blue!60!black,citecolor=blue!60!black,urlcolor=blue!60!black]{hyperref}

% Captions
\usepackage[font=small,labelfont=bf]{caption}

% Section formatting
\usepackage{titlesec}
\titleformat{\section}{\large\bfseries}{\thesection}{1em}{}
\titleformat{\subsection}{\normalsize\bfseries}{\thesubsection}{1em}{}
\titleformat{\subsubsection}{\normalsize\itshape}{\thesubsubsection}{1em}{}

% Custom commands
\newcommand{\pp}{\text{pp}}
\newcommand{\EUR}{\texteuro}
\newcommand{\code}[1]{\texttt{#1}}   % for code/variable names inline
```

**Rule:** Copy this block verbatim at the start of every new `.tex` file. Do **not** change the babel language, biblatex backend, or font stack between documents — differences cause inconsistent output and hard-to-diagnose errors.

---

## Quick diagnosis checklist

When a document fails to compile:

1. `grep "^!" <doc>.log | head -10` — find the first fatal error  
2. Is it a missing `.sty`? → `tlmgr install <package>` + `sudo mktexlsr`  
3. Is it a babel or biber error? → check packages above + `latexmk -C` to clear cache  
4. Is it a version mismatch? → point tlmgr to the correct historic mirror  
5. Still failing? → `latexmk -C` then recompile from scratch  

---

## Installed required packages (as of March 2026)

Run this block once on a new machine to install everything needed by the GMT thesis:

```bash
# Switch tlmgr to the matching historic mirror first:
tlmgr option repository https://ftp.tu-chemnitz.de/pub/tug/historic/systems/texlive/2025/tlnet-final/

tlmgr install \
  parskip \
  babel-english \
  biblatex \
  biber \
  csquotes \
  booktabs \
  longtable \
  caption \
  titlesec \
  setspace \
  geometry \
  lmodern \
  pdflscape \
  multirow \
  tabularx

sudo mktexlsr
```
