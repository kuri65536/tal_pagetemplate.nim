#! /bin/bash
function build() {
    nimble build
}


function test() {
    b=tests/catalog
    d=$b/en/LC_MESSAGES
    mkdir -p $d
    f=test;    msgfmt -o $d/$f.mo $b/$f.po
    f=another; msgfmt -o $d/$f.mo $b/$f.po
    testament pattern 'tests/*.nim'
    testament html
    mkdir -p html
    mv -f testresults.html html
}


function doc() {
    nim doc --outdir:html src/i18n.nim
    cd html; ln -sf i18n.html index.html
}


case "x$1" in
xdoc)
    doc
    ;;
xtest)
    test
    ;;
*)
    build
    ;;
esac
