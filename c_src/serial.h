#ifndef SERIAL_H
#define SERIAL_H

#include <stdio.h>
#include <stdlib.h>
#include <termios.h>
#include <fcntl.h>

typedef unsigned char byte;
typedef struct {
    int rate;
    speed_t speed;
} bit_rate;


#define MAXSPEED 23
static bit_rate bitrate_table[MAXSPEED] = {
    {0      , B0     },
    {50     , B50    },
    {75     , B75    },
    {110    , B110   },
    {134    , B134   },
    {150    , B150   },
    {200    , B200   },
    {300    , B300   },
    {600    , B600   },
    {1200   , B1200  },
    {1800   , B1800  },
    {2400   , B2400  },
    {4800   , B4800  },
    {9600   , B9600  },
    {19200  , B19200 },
    {38400  , B38400 },
    {57600  , B57600 },
    {115200 , B115200 },
    {230400 , B230400 }
};

#define OK 0x1001
#define INVALID_PATH 0x1002
#define INVALID_SETTINGS 0x1003
#define INVALID_I_SPEED 0x1004
#define INVALID_O_SPEED 0x1005
#define UNABLE_TO_SET_ATTR 0x1006
#define PORT_NOT_OPEN 0x1007
#define INVALID_SERIAL_SPEED 0x1008
#define UNABLE_TO_WRITE_DATA 0x1009

typedef struct {
    int code;
    const char *msg;
} err_code;

#define MAXERRORCODE 9
static err_code msg_lookup_table[MAXERRORCODE] = {
    {OK, "ok"},
    {INVALID_PATH, "invalid_path"},
    {INVALID_SETTINGS, "inavlid_settings"},
    {INVALID_I_SPEED, "invalid_i_speed"},
    {INVALID_O_SPEED, "invalid_o_speed"},
    {UNABLE_TO_SET_ATTR, "unable_to_set_attr"},
    {PORT_NOT_OPEN, "port_not_open"},
    {INVALID_SERIAL_SPEED, "inavlid_serial_speed"},
    {UNABLE_TO_WRITE_DATA, "unable_to_write_data"}
};

int serial_open(char *path, int bitrate, int *serial_fd);
int serial_speed(int fd, int bitrate);
int serial_write(int fd, byte *buf, int bytes);
const char *get_error_msg(int code);

#endif
