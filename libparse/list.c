#include <stdlib.h>
#include <stdio.h>
#include "list.h"


NODE *listNew()
{

    NODE *node;
    if(!(node=malloc(sizeof(NODE)))) return NULL;
    node->data=NULL;
    node->next=NULL;
    return node;
}

NODE *_list_create(void *data)
{
    NODE *node;
    if(!(node=malloc(sizeof(NODE)))) return NULL;
    node->data=data;
    node->next=NULL;
    return node;
}

void * listHead(NODE * n){
    return n->data;
}

NODE * listTail(NODE * n){
    return n->next;
}


void listSet(NODE * n, void * data){
    n->data = data;
}


NODE *listAddAfter(NODE *node, void *data)
{
    NODE *newnode;
    newnode= _list_create(data);
    newnode->next = node->next;
    node->next = newnode;
    return newnode;
}

NODE * listAddLast(NODE * first, void * data){

    if(first->next == NULL && first->data == NULL){
        first->data = data;
        return first;
    }

    NODE *newnode;
    newnode= _list_create(data);

    NODE *current = first;
    while (current->next != NULL) {
        current = current->next;
    }
    current->next = newnode;
    return newnode;

}

//list remove

void list_remove(NODE *list, int index) {//todo:test!
    int i = 0;

    while (list->next && i < index-1) {
        list = list->next;
        i++;
    }

    if(!list->next)//last one,can't delete
        return;

    NODE * tmp = list->next;
    if(!list->next->next)//this is one before the last one
        list->next = NULL;
    else
        list->next = list->next->next;

    free(tmp);
}



//list concat
NODE * listConcate (NODE *head1, NODE *head2)
{
    NODE  *p;
    if (head1==NULL)                            //if the first linked
        return (head2);
    if (head2==NULL)                            //if second linked
        return (head1);

    p=head1;                             //place p on the first
    while (p->next!=NULL)                 //move p to the last node
        p=p->next;
    p->next=head2;                           //address

    return (head1);
}

//void listPrint(NODE *start) {
//    NODE *temp;  //Declare temp
//    temp = start;       //Assign Starting Address to temp
//    while(temp!=NULL)
//    {
//        printf("%s\n",((Element *)(temp->data))->html);
//        temp=temp->next;
//    }
//}