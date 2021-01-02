src:= \
    src/tal_pagetemplate.nim \
    src/tal_pagetemplate/$(wildcard *.nim)

test: tests/catalog/en/LC_MESSAGES/test.mo
	nimble test

tests/catalog/en/LC_MESSAGES/test.mo: tests/catalog/en.po
	cd tests/catalog; mkdir -p en/LC_MESSAGES/
	cd tests/catalog; msgfmt -o en/LC_MESSAGES/test.mo $(notdir $<)

demo: nimptal
	./$< || echo
	./$< -a tests/test.json tests/test.xml

nimptal: tests/cmdline.nim $(src)
	nim c -o=$@ $<

