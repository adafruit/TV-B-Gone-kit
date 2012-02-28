#include <avr/pgmspace.h>

uint8_t internal_eeprom_read(uint16_t addr);
void internal_eeprom_write(uint16_t addr, uint8_t data);
void delay_ms(uint16_t ms);
void uart_init(uint16_t baud);
void uart_putchar(char c) ;
char uart_getchar(void);
char uart_getch(void);
void putnum_ud(uint16_t n);
void putnum_uh(uint16_t n);
void printhex(uint8_t hex);
void ROM_putstring(const char *str, uint8_t) ;
void RAM_putstring(char *str, uint8_t) ;
uint16_t uart_read16(void);
void print_div(void);

#define putstring(x) ROM_putstring(PSTR(x), 0)
#define putstring_nl(x) ROM_putstring(PSTR(x), 1)
//#define putstring(x) RAM_putstring(x)

#define NOP __asm__ __volatile__ ("nop")

