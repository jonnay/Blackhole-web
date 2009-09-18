;; Examples that illustrate the primary high-level functions of the
;; SSAX-SXML package

;-------------------------------------------------
; A macro for pretty printing the code as it is evaluated

; Pretty print the code as it is evatuated
(define-macro (pp-code-eval . thunk)
  `(begin
     ,@(apply
        append  ; should better use `map-union' from "sxpathlib.scm"
        (map
         (lambda (s-expr)
           (cond
             ((string? s-expr)  ; string - just display it
              `((display ,s-expr)
                (newline)))
             ((and (pair? s-expr) (eq? (car s-expr) 'define))
              ; definition - pp and eval it
              `((pp ',s-expr)
                ,s-expr))
             ((and (pair? s-expr)
                   (memq (car s-expr) '(newline cond-expand)))
              ; just eval it
              `(,s-expr))
             (else  ; for anything else - pp it and pp result
              `((pp ',s-expr)
                (display "==>")
                (newline)
                (pp ,s-expr)
                (newline)))))
         thunk))))
