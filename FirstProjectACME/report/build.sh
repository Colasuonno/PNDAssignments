#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
pdflatex -interaction=nonstopmode -halt-on-error -jobname=report report.tex >/dev/null
pdflatex -interaction=nonstopmode -halt-on-error -jobname=report report.tex >/dev/null
rm -f report.aux report.log report.out report.toc
echo "report.pdf built."
