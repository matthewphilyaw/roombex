#include <time.h>
#include <unistd.h>
#include <ctype.h>

#include "erl_interface.h"
#include "ei.h"
#include "serial.h"

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

int main(int argc, char **argv) {
    char *device_name;
    char *baudrate;
    int flag;

    while ((flag = getopt(argc, argv, "D:b:")) != -1) {
        switch (flag) {
            case 'D':
                device_name = optarg;
                break;
            case 'b':
                baudrate = optarg;
                break;
            case '?':
                if (optopt == 'D' || optopt == 'b')
                    fprintf (stderr, "Option -%c requires an argument.\n", optopt);
                else if (isprint (optopt))
                    fprintf (stderr, "Unknown option `-%c'.\n", optopt);
                else
                    fprintf (stderr,
                             "Unknown option character `\\x%x'.\n",
                             optopt);
                return 1;
            default:
                abort();
        } 
    }

    // setup timeout for calls
    struct timespec ts;
    ts.tv_sec = 0;
    ts.tv_nsec = 1 * 1000000;
    
    int serial_fd = 0;
    
    ETERM *tuplep, *intp;
    ETERM *fnp, *room_command;
    int res;
    byte buf[100];
    long allocated, freed;

    erl_init(NULL, 0);

    res = serial_open(device_name,
                      strtol(baudrate, (char **)NULL, 10),
                      &serial_fd);

    intp = erl_mk_atom(get_error_msg(res));
    erl_encode(intp, buf);
    write_cmd(buf, erl_term_len(intp));

    erl_free_term(fnp);
    erl_free_term(intp);

    while (read_cmd(buf) > 0) {
        res = OK;
        tuplep = erl_decode(buf);
        fnp = erl_element(1, tuplep);
        if (strncmp(ERL_ATOM_PTR(fnp), "command", 7) == 0) {
            room_command = erl_element(2, tuplep); 
            
            res = serial_write(serial_fd,
                               ERL_BIN_PTR(room_command),
                               ERL_BIN_SIZE(room_command));

            nanosleep(&ts, NULL);
            
            erl_free_term(room_command);
        } else if (strncmp(ERL_ATOM_PTR(fnp), "sensor", 6) == 0) {
            room_command = erl_element(2, tuplep); 
            
            res = serial_write(serial_fd,
                               ERL_BIN_PTR(room_command),
                               ERL_BIN_SIZE(room_command));
            
            nanosleep(&ts, NULL);
            
            // need to read data

            erl_free_term(room_command);
        }

        intp = erl_mk_atom(get_error_msg(res));
        erl_encode(intp, buf);
        write_cmd(buf, erl_term_len(intp));
        
        erl_free_compound(tuplep);
        erl_free_term(fnp);
        erl_free_term(intp);
    }
}
