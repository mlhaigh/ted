#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>
#include <string.h>
#include "cJSON.h"
#include <stdint.h>
#include <ctype.h>
#include "parse.h"

char *_scrape(char *script) {
    int pipefd[2];
    pid_t cpid;
    int status;

    FILE *file_ptr;
    char *buffer = NULL, *temp = NULL;

    if (pipe(pipefd) == -1) return NULL;

    if ((cpid = fork()) == -1) {
        return NULL;
    } else if (cpid == 0) {
        close(pipefd[0]);
        dup2(pipefd[1], STDOUT_FILENO);
        dup2(pipefd[1], STDERR_FILENO);

        execl("/usr/bin/nodejs", "nodejs", "-e", script, NULL);
        return NULL;
    }


    close(pipefd[1]);

    size_t sz = 0, idx = 0;
    int chr = EOF;

    file_ptr = fdopen(pipefd[0], "r");
    if (file_ptr != NULL) {
        while (chr) {
            chr = fgetc(file_ptr);
            if (chr == EOF) chr = 0;

            if (sz <= idx) {
                sz++;
                if ((temp = realloc(buffer, sz)) == NULL) {
                    free(buffer);
                    break;
                }
                buffer = temp;
            }
            buffer[idx++] = (char) chr;
        }
    }

    if (waitpid(cpid, &status, 0) == -1) return NULL;

    return buffer;
}
Page *pageFetch(char *url) {
    Page *page = malloc(sizeof(Page));
    char *buffer = NULL;
    asprintf(&buffer, "var phantom = require('phantom'); phantom.create(function (ph) { ph.createPage(function (page) { page.set('viewportSize', {width: 1366, height: 768}); page.open('%s', function () { page.includeJs('http://code.jquery.com/jquery-1.11.3.min.js', function () { page.evaluate(function () { return window.document.documentElement.outerHTML; }, function (result) { var str = JSON.stringify(result); console.log(str.substring(1, str.length - 1)); ph.exit(); }); }); }); }); });", url);
    if (buffer == NULL) return NULL;

    page->url = strdup(url);
    char *str = _scrape(buffer);
    str[strlen(str) - 1] = 0;
    page->html = str;


    free(buffer);
    return page;
}
NODE *pageFind(Page *page, char *sel) {
    char *buffer = NULL;
    asprintf(&buffer, "var phantom = require('phantom'); phantom.create(function (ph) { ph.createPage(function (page) { page.set('viewportSize', {width: 1366, height: 768}); page.set('content', \"%s\"); page.includeJs('http://code.jquery.com/jquery-1.11.3.min.js', function () { page.evaluate(function () { var css_path = function(el) { if (!(el instanceof Element)) return; var path = []; while (el.nodeType === Node.ELEMENT_NODE) { var selector = el.nodeName.toLowerCase(); if (el.id) { selector += '#' + el.id; path.unshift(selector); break; } else { var sib = el, nth = 1; while (sib = sib.previousElementSibling) { if (sib.nodeName.toLowerCase() == selector) nth++; } if (nth != 1) selector += ':nth-of-type('+nth+')'; } path.unshift(selector); el = el.parentNode; } return path.join(' > '); }; return $.map($('%s'), function (elm) { return {html: elm.outerHTML, path: css_path(elm)} }); /*return $.find(blue[0]).length;*/ }, function (result) { console.log(JSON.stringify(result)); ph.exit(); }); }); }); });", page->html, sel);
    if (buffer == NULL) return NULL;

    cJSON *json;
    char *str = _scrape(buffer);
    json = cJSON_Parse(str);
    if (json == NULL)
        return NULL;

    NODE * head = listNew();

    int i;
    for (i = 0; i < cJSON_GetArraySize(json); i++) {
        Element * e = malloc(sizeof(Element));
        e->html = strdup(cJSON_GetObjectItem(cJSON_GetArrayItem(json, i), "html")->valuestring);
        e->path = strdup(cJSON_GetObjectItem(cJSON_GetArrayItem(json, i), "path")->valuestring);
        listAddLast(head,e);
    }

    free(buffer);
    cJSON_Delete(json);
    return head;
}


/*Element*/
char * _runOnElement(Element * element,char * code){
    int size = sizeof(char) * strlen(element->html)*2;
    char * innerHtml = malloc(size);
    str_escape(innerHtml,element->html,size);
    char *buffer = NULL;
    asprintf(&buffer, "var phantom = require('phantom'); phantom.create(function (ph) { ph.createPage(function (page) { page.set('viewportSize', {width: 1366, height: 768}); page.set('content',\"\"); page.includeJs('http://code.jquery.com/jquery-1.11.3.min.js', function () { page.evaluate(function () { return obj = {text:$(\"%s\").%s}; }, function (result) { console.log(JSON.stringify(result)); ph.exit(); }); }); }); });", innerHtml,code);
    if (buffer == NULL) return NULL;

    cJSON *json;
    char *str = _scrape(buffer);
    //printf("str: %s",str);
    json = cJSON_Parse(str);
    if (json == NULL)
        return NULL;
    json = cJSON_GetObjectItem(json,"text");
    if (json == NULL)
        return NULL;
    free(innerHtml);
    return json->valuestring;
}
char * elementAttr(Element * element, char * attr){
    if (element->html == NULL)
        return NULL;
    int size = sizeof(char) * strlen(element->html)*2;
    char * innerHtml = malloc(size);
    str_escape(innerHtml,element->html,size);
    char *buffer = NULL;
    asprintf(&buffer, "var phantom = require('phantom'); phantom.create(function (ph) { ph.createPage(function (page) { page.set('viewportSize', {width: 1366, height: 768}); page.set('content',\"\"); page.includeJs('http://code.jquery.com/jquery-1.11.3.min.js', function () { page.evaluate(function () { return obj = {attr:$(\"%s\").attr('%s')}; }, function (result) { console.log(JSON.stringify(result)); ph.exit(); }); }); }); });", innerHtml, attr);
    if (buffer == NULL) return NULL;

    cJSON *json;
    char *str = _scrape(buffer);
    json = cJSON_Parse(str);
    if (json == NULL)
        return NULL;
    json = cJSON_GetObjectItem(json,"attr");
    if (json == NULL)
        return NULL;
    free(innerHtml);
    return json->valuestring;
}
char * elementText(Element * element){
    return _runOnElement(element,"text()");
}
char * elementType(Element * element){
    return _runOnElement(element,"get(0).tagName");
}
NODE * elementChildren(Page * page, Element * element) {
    char *buffer = NULL;
    asprintf(&buffer, "var phantom = require('phantom'); phantom.create(function (ph) { ph.createPage(function (page) { page.set('viewportSize', {width: 1366, height: 768}); page.set('content', '%s'); page.includeJs('http://code.jquery.com/jquery-1.11.3.min.js', function () { page.evaluate(function () { var css_path = function(el) { if (!(el instanceof Element)) return; var path = []; while (el.nodeType === Node.ELEMENT_NODE) { var selector = el.nodeName.toLowerCase(); if (el.id) { selector += '#' + el.id; path.unshift(selector); break; } else { var sib = el, nth = 1; while (sib = sib.previousElementSibling) { if (sib.nodeName.toLowerCase() == selector) nth++; } if (nth != 1) selector += \":nth-of-type(\"+nth+\")\"; } path.unshift(selector); el = el.parentNode; } return path.join(\" > \"); }; return $.map($('%s').children(), function (elm) { return {html: elm.outerHTML, path: css_path(elm)} }); /*return $.find(blue[0]).length;*/ }, function (result) { console.log(JSON.stringify(result)); ph.exit(); }); }); }); });", page->html,element->path);
    if (buffer == NULL) return NULL;
    cJSON *json;
    char *str = _scrape(buffer);
    json = cJSON_Parse(str);
    if (json == NULL)
        return NULL;

    NODE * head = listNew();

    int i;
    for (i = 0; i < cJSON_GetArraySize(json); i++) {
        Element * e = malloc(sizeof(Element));
        e->html = strdup(cJSON_GetObjectItem(cJSON_GetArrayItem(json, i), "html")->valuestring);
        e->path = strdup(cJSON_GetObjectItem(cJSON_GetArrayItem(json, i), "path")->valuestring);
        listAddLast(head,e);
    }

    free(buffer);
    cJSON_Delete(json);
    return head;
}

/* Page */
char * pageURL(Page * p){
    return p->url;
}
char * pageHTML(Page * p){
    return p->html;
}
Element * pageRoot(Page * p){
    Element * element = malloc(sizeof(element));
    element->path = "html";
    element->html = p->html;
    return element;
}


char * elementHTML(Element * element){
    return element->html;
}

size_t str_escape(char *dst, const char *src, size_t dstLen)
{
    const char complexCharMap[] = "abtnvfr";

    size_t i;
    size_t srcLen = strlen(src);
    size_t dstIdx = 0;

    // If caller wants to determine required length (supplying NULL for dst)
    // then we set dstLen to SIZE_MAX and pretend the buffer is the largest
    // possible, but we never write to it. Caller can also provide dstLen
    // as 0 if no limit is wanted.
    if (dst == NULL || dstLen == 0) dstLen = SIZE_MAX;

    for (i = 0; i < srcLen && dstIdx < dstLen; i++)
    {
        size_t complexIdx = 0;

        switch (src[i])
        {
            case '\'':
            case '\"':
            case '\\':
                if (dst && dstIdx <= dstLen - 2)
                {
                    dst[dstIdx++] = '\\';
                    dst[dstIdx++] = src[i];
                }
                else dstIdx += 2;
                break;

            case '\r': complexIdx++;
            case '\f': complexIdx++;
            case '\v': complexIdx++;
            case '\n': complexIdx++;
            case '\t': complexIdx++;
            case '\b': complexIdx++;
            case '\a':
                if (dst && dstIdx <= dstLen - 2)
                {
                    dst[dstIdx++] = '\\';
                    dst[dstIdx++] = complexCharMap[complexIdx];
                }
                else dstIdx += 2;
                break;

            default:
                if (isprint(src[i]))
                {
                    // simply copy the character
                    if (dst)
                        dst[dstIdx++] = src[i];
                    else
                        dstIdx++;
                }
                else
                {
                    // produce octal escape sequence
                    if (dst && dstIdx <= dstLen - 4)
                    {
                        dst[dstIdx++] = '\\';
                        dst[dstIdx++] = ((src[i] & 0300) >> 6) + '0';
                        dst[dstIdx++] = ((src[i] & 0070) >> 3) + '0';
                        dst[dstIdx++] = ((src[i] & 0007) >> 0) + '0';
                    }
                    else
                    {
                        dstIdx += 4;
                    }
                }
        }
    }

    if (dst && dstIdx <= dstLen)
        dst[dstIdx] = '\0';

    return dstIdx;
}


//Element *parent(Element *elm) {
//    return NULL;
//}
//
//Element *children(Element *elm) {
//    return NULL;
//}
