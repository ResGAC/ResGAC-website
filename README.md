# ResGAC — project page (anonymous)

Static project page for a double-blind submission. No build step: GitHub Pages
serves these files directly (`.nojekyll` disables the Jekyll build).

```
index.html                 project page — video first, details in <details> panels
details.html               full training details / appendix
assets/css/style.css       all styling
assets/{videos,imgs,pdfs}/ media
tools/serve.sh             local preview at :8000
tools/check_anonymity.sh   pre-push anonymity gate
tools/check_links.sh       find references to missing media
tools/scrub_media.sh       strip metadata from videos/images
tools/stamp_css.sh         version the stylesheet link after editing CSS
```

Author names, affiliations, and the code repository are withheld during review.
