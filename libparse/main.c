#include <stdio.h>
#include "parse.h"


int main(int argc, char *argv[]) {
    Page *page = pageFetch("http://www.cs.columbia.edu/~sedwards/");
//    printf("%s\n", page->url);
//    printf("%s\n", page->html);

    NODE * first = pageFind(page, "#titlebar");


    printf("id:  %s\n",elementAttr((Element*)listHead(first), "id"));
    printf("text:  %s\n",elementText((Element*)listHead(first)));
    printf("type:  %s\n\n\n",elementType((Element*)listHead(first)));

    NODE *child_list = elementChildren(page, (Element*)listHead(first));
    Element * e = (Element*)listHead(listTail(child_list));

    printf("text first child:  %s\n",elementText(e));
    printf("type first child:  %s\n",elementType(e));
    printf("id first child:  %s\n",elementAttr(e,"id"));

//
//    NODE * first = listNew();
//    listAddLast(first, "a");
//    listAddLast(first, "b");
//    listAddLast(first, "c");
//    listAddLast(first, "c");
//    listAddLast(first, "d");
//    listAddLast(first, "e");
//    listPrint(first);
//    printf("\n");
//    list_remove(first,3);
//
//    listPrint(first);
//    printf("\n");
//
//    NODE * newFirst = listNew();
//    NODE * f = listAddLast(newFirst, "f");
//    listAddAfter(f,"G");
//    listAddLast(newFirst, "h");
//    listConcate(first,newFirst);
//    listPrint(first);
//    printf("\n");
//    listSet(f,"F Modified");
//    listPrint(first);
//
//
//    printf("should be a: %s\n",listHead(first));
//    printf("should be b: %s\n",listHead(listTail(first)));
    return 0;
}

