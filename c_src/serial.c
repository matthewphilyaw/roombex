#include <termios.h>
#include <fcntl.h>
#include <stdlib.h>

#include "erl_interface.h"
#include "ei.h"

typedef unsigned char byte;
typedef struct {
    int rate;
    speed_t speed;
} bit_rate;

int bytes_read;
int serial_bytes_read;
int serial_fd = 0;
char serial_buf[100];

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


static speed_t get_speed(int speed)
{
    int i;

    for(i=0 ; i < MAXSPEED ; i++)
    {
        if (speed == bitrate_table[i].rate)
        {
            return bitrate_table[i].speed;
        }
    }

    perror("invalid_serial_speed");
    exit(1);
}

int serial_open(char *path, int speed) {
    int fd = 0;
    struct termios tio;
    int int_speed = -1;

    fd = open(path, O_RDWR | O_NOCTTY | O_NDELAY);
    if (fd <0) {
        fprintf(stderr, "%i invalid path _%s_", fd, path);
        exit(-1);
    }


    if (tcgetattr(fd,&tio) < 0)
    {
        fprintf(stderr, "invalid settings");
        exit(-1);
    }

    tio.c_cc[VMIN] = 5;         /* at least one character */
    tio.c_cc[VTIME] = 0;        /* do not wait to fill buffer */

    tio.c_iflag &= ~(ICRNL |    /* disable CR-to-NL mapping */
            INLCR |    /* disable NL-to-CR mapping */
            IGNCR |    /* disable ignore CR */
            ISTRIP |   /* disable stripping of eighth bit */
            IXON |     /* disable output flow control */
            BRKINT |   /* disable generate SIGINT on brk */
            IGNPAR |
            PARMRK |
            IGNBRK |
            INPCK);    /* disable input parity detection */

    tio.c_lflag &= ~(ICANON |   /* enable non-canonical mode */
            ECHO |     /* disable character echo */
            ECHOE |    /* disable visual erase */
            ECHOK |    /* disable echo newline after kill */
            ECHOKE |   /* disable visual kill with bs-sp-bs */
            ECHONL |   /* disable echo nl when echo off */
            ISIG |     /* disable tty-generated signals */
            IEXTEN);   /* disable extended input processing */

    tio.c_cflag |= CS8;         /* enable eight bit chars */
    tio.c_cflag &= ~PARENB;     /* disable input parity check */
    tio.c_oflag &= ~OPOST;      /* disable output processing */
    tio.c_cflag |= CLOCAL;

    if (cfsetispeed(&tio,get_speed(speed)) < 0)
    {
        fprintf(stderr, "invalid ispeed");
        exit(-1);
    }

    if (cfsetospeed(&tio,get_speed(speed)) < 0)
    {
        fprintf(stderr, "invalid ospeed");
        exit(-1);
    }

    tio.c_cflag |= CRTSCTS;

    if (tcsetattr(fd, TCSAFLUSH, &tio) < 0)
    {
        fprintf(stderr, "problem setting attrs");
        exit(-1);
    }

    return fd;
}

void serial_speed(int fd, int speed) {
    struct termios tio;

    if(fd==0) {
        fprintf(stderr, "Serial Port %i not open", fd);
        exit(-1);
    }

    if (tcgetattr(fd,&tio) < 0)
    {
        fprintf(stderr, "invalid settings");
        exit(-1);
    }

    if (cfsetispeed(&tio,get_speed(speed)) < 0)
    {
        fprintf(stderr, "invalid ispeed");
        exit(-1);
    }

    if (cfsetospeed(&tio,get_speed(speed)) < 0)
    {
        fprintf(stderr, "invalid ospeed");
        exit(-1);
    }

    if (tcsetattr(fd, TCSAFLUSH, &tio) < 0)
    {
        fprintf(stderr, "problem setting attrs");
        exit(-1);
    }
}

void serial_write(int fd, byte *buf, int bytes) {
    write(fd, buf, bytes);
}

read_cmd(byte *buf)
{
    int len;

    if (read_exact(buf, 2) != 2)
        return(-1);
    len = (buf[0] << 8) | buf[1];
    return read_exact(buf, len);
}

write_cmd(byte *buf, int len)
{
    byte li;

    li = (len >> 8) & 0xff;
    write_exact(&li, 1);

    li = len & 0xff;
    write_exact(&li, 1);

    return write_exact(buf, len);
}

read_exact(byte *buf, int len)
{
    int i, got=0;

    do {
        if ((i = read(0, buf+got, len-got)) <= 0)
            return(i);
        got += i;
    } while (got<len);

    return(len);
}

write_exact(byte *buf, int len)
{
    int i, wrote = 0;

    do {
        if ((i = write(1, buf+wrote, len-wrote)) <= 0)
            return (i);
        wrote += i;
    } while (wrote<len);

    return (len);
}

int main() {
    ETERM *tuplep, *intp;
    ETERM *fnp, *port_name, *port_speed, *data;
    int res;
    byte buf[100];
    long allocated, freed;

    erl_init(NULL, 0);

    while (read_cmd(buf) > 0) {
        tuplep = erl_decode(buf);
        fnp = erl_element(1, tuplep);

        if (strncmp(ERL_ATOM_PTR(fnp), "open", 4) == 0) {
            fprintf(stderr, "Open command found\n");
            port_name = erl_element(2, tuplep);
            port_speed = erl_element(3, tuplep);
            
            serial_fd =  serial_open(erl_iolist_to_string(port_name), 
                                     ERL_INT_VALUE(port_speed));

            fprintf(stderr, "Port opened\n");
            res = 0;
        } else if (strncmp(ERL_ATOM_PTR(fnp), "send", 4) == 0) {
            fprintf(stderr, "Send command found\n");
            data = erl_element(2, tuplep); 
            serial_write(serial_fd,
                         ERL_BIN_PTR(data),
                         ERL_BIN_SIZE(data));
            fprintf(stderr, "sent\n");

            res = 1;
        }

        intp = erl_mk_int(res);
        erl_encode(intp, buf);
        write_cmd(buf, erl_term_len(intp));

        erl_free_compound(tuplep);
        erl_free_term(fnp);
        erl_free_term(port_name);
        erl_free_term(port_speed);
        erl_free_term(data);
        erl_free_term(intp);
    }
}
