src:= \
    src/tal_pagetemplate.nim \
    src/tal_pagetemplate/$(wildcard *.nim)

test: tests/catalog/en/LC_MESSAGES/test.mo \
      tests/catalog/en/LC_MESSAGES/another.mo
	nimble test

tests/catalog/en/LC_MESSAGES/test.mo: tests/catalog/test.po
	cd tests/catalog; mkdir -p en/LC_MESSAGES/
	cd tests/catalog; msgfmt -o en/LC_MESSAGES/test.mo $(notdir $<)

tests/catalog/en/LC_MESSAGES/another.mo: tests/catalog/another.po
	cd tests/catalog; mkdir -p en/LC_MESSAGES/
	cd tests/catalog; msgfmt -o en/LC_MESSAGES/another.mo $(notdir $<)

catalogs: tests/catalog/en/LC_MESSAGES/test.mo \
          tests/catalog/en/LC_MESSAGES/another.mo

demo: nimptal
	./$< || echo
	./$< -a tests/test.json -i en,UTF-8,test,$(PWD)/tests/catalog \
	    tests/test.xml

nimptal: tests/cmdline.nim $(src)
	nim c -o=$@ $<

