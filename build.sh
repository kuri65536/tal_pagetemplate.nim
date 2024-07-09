#! /bin/bash
function build() {
    nimble build
}


function pretest() {
    b=tests/catalog
    d=$b/en/LC_MESSAGES
    mkdir -p $d
    f=test;    msgfmt -o $d/$f.mo $b/$f.po
    f=another; msgfmt -o $d/$f.mo $b/$f.po
}


function test() {
    testament pattern 'tests/test*.nim'
    testament html
    mkdir -p html
    mv -f testresults.html html
}


function doc() {
    nim doc --outdir:html src/tal_pagetemplate.nim
    cd html; ln -sf tal_pagetemplate.html index.html
}


case "x$1" in
xdoc)
    doc
    ;;
xpre-test)
    pretest
    ;;
xtest)
    pretest
    test
    ;;
*)
    build
    ;;
esac
