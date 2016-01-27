#ifndef PARSE_PARSE_H
#define PARSE_PARSE_H

#define mu_assert(message, test) do { if (!(test)) return message; } while (0)
#define mu_run_test(test) do { char *message = test(); tests_run++; if (message) return message; } while (0)
extern int tests_run;

typedef struct Page {
    char *url;
    char *html;
} Page;

typedef struct Element {
    char *html;
    char *path;
} Element;


char *_scrape(char *script);
size_t str_escape(char *dst, const char *src, size_t dstLen);


/*Page*/
Page *pageFetch(char *url);
NODE *pageFind(Page *page, char *sel);
char *pageURL(Page *p);
char *pageHTML(Page *p);
Element *pageRoot(Page *p);


/*Element*/
char *_runOnElement(Element *element, char *code);
char *elementText(Element *element);
char *elementType(Element *element);
char *elementAttr(Element *element, char *attr);
NODE * elementChildren(Page *page, Element *element);

#endif
