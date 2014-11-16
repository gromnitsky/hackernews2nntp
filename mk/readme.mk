html := $(patsubst %.md, %.html, $(wildcard *.md))
clean += $(html)

%.html: %.md
	pandoc $< -o $@
