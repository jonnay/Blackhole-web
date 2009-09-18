; Project description to be handled by Module Manager
(project
 ;(src-dir "../Ssax-sxml/")  ; default here
 (dest-dir
  (bigloo "_bigloo/ssax-sxml/")
  (chicken "_chicken/ssax-sxml/")
  (gambit "_gambit/ssax-sxml/")
  (plt "_plt/ssax-sxml/"))
 
 (library ssax-sxml
  
  ; Common files
  (common
   (file
    (bigloo "libs/bigloo/common.scm")
    (plt "libs/plt/common.scm")
    (chicken "libs/chicken/common.scm")
    (gambit "libs/gambit/common.scm")))
  (myenv
   (file
    (bigloo "libs/bigloo/myenv-bigloo.scm")
    (plt "libs/plt/myenv.scm")
    (chicken "libs/chicken/myenv.scm")
    (gambit "libs/gambit/myenv.scm"))
   (plt:verbatim  ; To be inserted to PLT module header as-is
    (require (lib "defmacro.ss"))))
  (srfi-13-local
   (file
    (plt (lib "string.ss" "srfi/13"))
    "libs/srfi-13-local.scm")
   (import common myenv)
   (plt:verbatim
    (require (lib "defmacro.ss"))))
  (util
   (file "libs/util.scm")
   (import common myenv srfi-13-local))
  
  ;---------------------------
  ; SSAX
  (parse-error
   (file
    (bigloo "libs/bigloo/parse-error.scm")
    (plt "libs/plt/parse-error.scm")
    (chicken "libs/chicken/parse-error.scm")
    (gambit "libs/gambit/parse-error.scm"))
   (import myenv))
  (input-parse
   (file "libs/input-parse.scm")
   (import common myenv parse-error)
   (plt:verbatim
    (require (lib "defmacro.ss"))))
  (look-for-str
   (file "libs/look-for-str.scm")   
   (import common myenv))
  (char-encoding
   (file "ssax/char-encoding.scm")
   (import common myenv))
  (ssax-code
   (file
    (plt "plt-specific/SSAX-code.scm")
    "ssax/SSAX-code.scm")
   (import common myenv srfi-13-local util
           parse-error input-parse look-for-str char-encoding)
   (plt:verbatim
    (require (lib "defmacro.ss"))))
  (tree-trans
   (file "ssax/SXML-tree-trans.scm")
   (import myenv))
  
  ;---------------------------
  ; Multi parser  
  (sxpathlib  ; SXPathlib - for "id.scm" and "xlink-parser.scm"
   (file "sxml-tools/sxpathlib.scm")
   (import common myenv srfi-13-local
           util ; sxml-tools
           )
   (plt:verbatim
    (require (rename (lib "pretty.ss") pp pretty-print))))
  (srfi-12
   (file "multi-parser/id/srfi-12.scm")
   (import myenv)
   (plt:verbatim
    (require (lib "defmacro.ss"))))
  (mime
   (file "multi-parser/id/mime.scm")
   (import common myenv input-parse srfi-13-local))
  (http
   (file "multi-parser/id/http.scm")
   (import common myenv mime srfi-12 util srfi-13-local)
   (chk:uses tcp)  ; Additional module uses for Chicken
   (plt:verbatim
    (require (lib "defmacro.ss"))))
  (access-remote
   (file "multi-parser/id/access-remote.scm")
   (import common myenv http srfi-12 util srfi-13-local))
  (id
   (file "multi-parser/id/id.scm")
   (import common myenv access-remote sxpathlib))
  (xlink-parser
   (file "sxml-tools/xlink-parser.scm")
   (import common myenv util srfi-13-local access-remote sxpathlib))
  (ssax-prim
   (file "multi-parser/ssax-prim.scm")
   (import ssax-code))
  (multi-parser   
   (file "multi-parser/multi-parser.scm")
   (import myenv srfi-13-local input-parse parse-error ssax-code
           ssax-prim id xlink-parser))
  
  ;---------------------------
  ; HTML Prag  
  (htmlprag
   (file "html-prag/htmlprag.scm")
   (import myenv))
  
  ;---------------------------
  ; SXML Tools
  (sxml-tools
   (file "sxml-tools/sxml-tools.scm")
   (import common myenv srfi-13-local
           util sxpathlib)
   (plt:verbatim
    (require (lib "defmacro.ss"))))
  (sxpath-ext
   (file "sxml-tools/sxpath-ext.scm")
   (import common myenv srfi-13-local
           util sxpathlib sxml-tools))  
  (xpath-parser
   (file "sxml-tools/xpath-parser.scm")
   (import common myenv srfi-13-local
           util sxpathlib sxml-tools))
  (txpath
   (file "sxml-tools/txpath.scm")
   (import common myenv srfi-13-local
           util sxpathlib sxml-tools sxpath-ext xpath-parser))
  (sxpath
   (file "sxml-tools/sxpath.scm")
   (import common myenv srfi-13-local
           util sxml-tools sxpathlib sxpath-ext txpath xpath-parser))
  (xpath-ast
   (file "sxml-tools/xpath-ast.scm")
   (import common myenv xpath-parser))
  (xpath-context
   (file "sxml-tools/xpath-context.scm")
   (import common myenv srfi-13-local
           util sxpathlib sxml-tools sxpath-ext xpath-parser txpath xpath-ast
           access-remote ssax-code htmlprag xlink-parser multi-parser xlink))
  (xlink
   (file "sxml-tools/xlink.scm")
   (import common myenv srfi-12 srfi-13-local util sxpathlib sxml-tools
           sxpath-ext xpath-parser txpath xpath-ast access-remote ssax-code
           htmlprag xlink-parser multi-parser xpath-context))
  (ddo-axes
   (file "sxml-tools/ddo-axes.scm")
   (import common myenv srfi-13-local 
           util sxpathlib sxml-tools xpath-context))
  (ddo-txpath
   (file "sxml-tools/ddo-txpath.scm")
   (import common myenv srfi-13-local
           util sxpathlib sxml-tools
           sxpath-ext xpath-parser txpath xpath-ast xpath-context ddo-axes))
  (lazy-xpath
   (file "sxml-tools/lazy-xpath.scm")
   (import common myenv srfi-13-local
           util sxpathlib sxml-tools sxpath-ext xpath-parser txpath xpath-ast 
           xpath-context))
  (lazy-ssax
   (file "ssax/lazy-ssax.scm")
   (import common myenv srfi-13-local util parse-error input-parse
           look-for-str char-encoding ssax-code
           sxpathlib sxml-tools sxpath-ext xpath-parser txpath xpath-ast 
           xpath-context lazy-xpath)
   (bgl:compiler-flags  ; Additional flags to be passed when compiling module
    "-call/cc"))
  (modif
   (file "sxml-tools/modif.scm")
   (import common myenv srfi-13-local
           util sxpathlib sxml-tools xpath-context xpath-ast ddo-txpath))
  (serializer
   (file "sxml-tools/serializer.scm")
   (import common myenv))
  (guides
   (file "sxml-tools/guides.scm")
   (import common myenv parse-error input-parse ssax-code))
 
  ;---------------------------
  ; STX
  (libmisc
   (file "stx/libmisc.scm")
   (import common myenv srfi-13-local util)
   (plt:verbatim
    (require (rename (lib "pretty.ss") pp pretty-print))))
  (stx-engine
   (file "stx/stx-engine.scm")
   (import common myenv srfi-13-local util parse-error input-parse
           look-for-str char-encoding ssax-code sxml-tools sxpathlib
           sxpath-ext txpath sxpath libmisc srfi-12 access-remote)
   (plt:verbatim
    (require (lib "defmacro.ss"))
    (require (rename (lib "pretty.ss") pp pretty-print))))
      
 )  ; end of library

 (application example

  ; Example to illustrate the SXML tools
  (example
   (file
    (plt "plt-specific/example.scm")
    "example.scm")
   (plt:verbatim
    (require (lib "defmacro.ss"))
    (require (rename (lib "pretty.ss") pp pretty-print))))

 )  ; end of application 'example

 (application test-sxml

  ; XP tester
  (xtest-lib
   (file "sxml-tools/tests/xtest-lib.scm")
   (plt:verbatim
    (require (rename (lib "pretty.ss") pp pretty-print))))
  (xtest-harness
   (file "sxml-tools/tests/xtest-harness.scm")
   (import xtest-lib)
   (plt:verbatim
    (require (lib "defmacro.ss"))
    (require (rename (lib "pretty.ss") pp pretty-print))))
  (xtest-maker
   (file "sxml-tools/tests/xtest-maker.scm")
   (import xtest-lib)
   (plt:verbatim
    (require (lib "defmacro.ss"))
    (require (rename (lib "pretty.ss") pp pretty-print))))

  ; Test fixture for SXML tools
  (vsxpathlib
   (file "sxml-tools/tests/vsxpathlib.scm")
   (plt:verbatim
    (require (lib "defmacro.ss"))
    (require (rename (lib "pretty.ss") pp pretty-print))))
  (vsxpath-ext
   (file "sxml-tools/tests/vsxpath-ext.scm")
   (import xtest-lib xtest-harness)
   (plt:verbatim
    (require (rename (lib "pretty.ss") pp pretty-print))))
  (vtxpath
   (file "sxml-tools/tests/vtxpath.scm")
   (import xtest-lib xtest-harness)
   (plt:verbatim
    (require (rename (lib "pretty.ss") pp pretty-print))))
  (vcontext
   (file "sxml-tools/tests/vcontext.scm")
   (import xtest-lib xtest-harness vsxpathlib)
   (plt:verbatim
    (require (lib "defmacro.ss"))
    (require (rename (lib "pretty.ss") pp pretty-print))))
  (vddo
   (file "sxml-tools/tests/vddo.scm")
   (import xtest-lib xtest-harness)
   (plt:verbatim
    (require (rename (lib "pretty.ss") pp pretty-print))))
  (vmodif
   (file "sxml-tools/tests/vmodif.scm")
   (import xtest-lib xtest-harness)
   (plt:verbatim
    (require (rename (lib "pretty.ss") pp pretty-print))))

  ; An example that simply loads all tests
  (test-sxml
   (file "test-sxml.scm")
   (import xtest-harness xtest-lib xtest-maker
           vsxpathlib vsxpath-ext vtxpath vcontext vddo vmodif))

 )  ; end of application 'test-sxml

 (standalone  ; standalone files
  "doc.txt"
  "prj-ssax-sxml.s"  ; self
  (bigloo 
    "XML/poem.xml"
    "XML/poem2html.xsl"
    "XML/doc.xml")
  (chicken
    "XML/poem.xml"
    "XML/poem2html.xsl"
    "XML/doc.xml")
  (gambit
    "XML/poem.xml"
    "XML/poem2html.xsl"
    "XML/doc.xml")
  (plt
    "info.ss"))

 (apidoc  ; API Doc description
  (chapter "Obtaining the SXML document from XML (HTML) by URI"
    sxml:document
    (section "High-level functions called by `sxml:document'"
      ssax:xml->sxml
      html->sxml
      open-input-resource))
  (chapter "SXPath: XPath for SXML"
    txpath
    sxpath)
  (chapter "SXML Transformations"
    (section "STX: Scheme-enabled XSLT Processor"   
      stx:make-stx-stylesheet
      stx:transform-dynamic)
    (section "Pre-post-order transformations"
      pre-post-order))
  (chapter "XPathLink: a Query Language with XLink support"
    xlink:documents
    sxpath/c)
  (chapter "SXML modifications"
    sxml:modify
    sxml:modify!)
  (chapter "DDO SXPath: the Polynomial-Time XPath Implementation"
    ddo:sxpath)
  (chapter "Lazy SXML processing"
    lazy:xml->sxml
    lazy:sxpath
    (section "Lower-level infrastructure for lazy SXML processing"
      lazy:result->list
      lazy:node->sxml))    
  (chapter "SXML Serialization"
    srl:sxml->xml
    srl:sxml->xml-noindent
    srl:sxml->html
    srl:sxml->html-noindent
    (section "Parameterizing the SXML serializer"
      srl:parameterizable)))

)
