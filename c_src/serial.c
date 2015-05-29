#include "serial.h"

static int get_speed(int bitrate, speed_t *speed) {
    int i;

    for(i=0 ; i < MAXSPEED ; i++) {
        if (bitrate == bitrate_table[i].rate) {
            *speed = bitrate_table[i].speed;
            return OK;
        }
    }
    
    return INVALID_SERIAL_SPEED;
}

const char *get_error_msg(int code) {
    int i;
    
    for (i = 0; i < MAXERRORCODE; i++) {
        if (code == msg_lookup_table[i].code) 
            return msg_lookup_table[i].msg;
    }
    
    // Maybe a cleaner way to handle this, but if error doesn't exist
    // that isn't something I can fix.
    perror("Invalid error code");
    exit(1);
}

int serial_open(char *path, int bitrate, int *serial_fd) {
    int fd = 0;
    struct termios tio;
    speed_t speed;

    fd = open(path, O_RDWR | O_NOCTTY | O_NDELAY);
    if (fd <0) {
        return INVALID_PATH;
    }


    if (tcgetattr(fd,&tio) < 0)
    {
        return INVALID_SETTINGS;
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
    
    int res = get_speed(bitrate, &speed);
    if (res != OK)
        return res;
    
    if (cfsetispeed(&tio, speed) < 0)
    {
        return INVALID_I_SPEED;
    }

    if (cfsetospeed(&tio,speed) < 0)
    {
        return INVALID_O_SPEED;
    }

    tio.c_cflag |= CRTSCTS;

    if (tcsetattr(fd, TCSAFLUSH, &tio) < 0)
    {
        return INVALID_SETTINGS;
    }

    // set serial fd
    *serial_fd = fd;
    return OK;
}

int serial_speed(int fd, int bitrate) {
    struct termios tio;
    speed_t speed;

    if(fd==0) {
        return PORT_NOT_OPEN;
    }
    
    int res = get_speed(bitrate, &speed);
    if (res != OK)
        return res;

    if (tcgetattr(fd,&tio) < 0)
    {
        return INVALID_SETTINGS;
    }

    if (cfsetispeed(&tio,speed) < 0)
    {
        return INVALID_I_SPEED;
    }

    if (cfsetospeed(&tio,speed) < 0)
    {
        return INVALID_O_SPEED;
    }

    if (tcsetattr(fd, TCSAFLUSH, &tio) < 0)
    {
        return INVALID_SETTINGS;
    }
}

int serial_write(int fd, byte *buf, int bytes) {
    if (write(fd, buf, bytes) < 0) return UNABLE_TO_WRITE_DATA; 

    return OK;
}
