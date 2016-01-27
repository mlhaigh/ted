typedef struct node_s {
    void *data;
    struct node_s *next;
} NODE;

NODE *listNew();
NODE *_list_create(void *data);
void * listHead(NODE * n);
NODE * listTail(NODE * n);
void listSet(NODE * n, void * data);
NODE *listAddAfter(NODE *node, void *data);
void list_remove(NODE *list, int index);
NODE * listConcate (NODE *head1, NODE *head2);
NODE * listAddLast(NODE * first, void * data);
void listPrint(NODE *start);