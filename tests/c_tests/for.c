#include<stdlib.h>
#include<stdio.h>

int main() {
    int x = 0;
    int y = 0;
    int a = 84;
    int b = 37;
    int c = 0;
    int i;
    int k;
    int j;
    int m;
    int n;
    int o;
    for (i = 0; i < 42; i = i + 1) {
        x = x + 1;
    }
    for (k = 0; k <= 41; k = k + 1) {
        y = y + 1;
    }
    for (j = 84; j >= 43; j = j - 1) {
        a = a - 1;
    }
    for (m = 100; m > 4; m = m / 2) {
        b = b + 1;
    }
    for (n = 1; n != 4; n = n + 1) {
        for (o = 0; o < 12; o = o + n) {
          c = c + 1;    
        }
    }
    c = c * 2;
    c = c + 2;
    printf("%d %d %d %d %d\n", x, y, a, b, c);
    return 0;
}
