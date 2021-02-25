#!/bin/sh

cd /home/jenkins/RTD

wget -O MathJax.js 'http://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML'

wget -O extensions/MathMenu.js 'http://cdn.mathjax.org/mathjax/latest/extensions/MathMenu.js?config=TeX-AMS-MML_HTMLorMML'
wget -O extensions/MathZoom.js 'http://cdn.mathjax.org/mathjax/latest/extensions/MathZoom.js?config=TeX-AMS-MML_HTMLorMML'
