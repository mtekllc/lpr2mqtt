#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <mosquitto.h>

#define BUFFER_SIZE 4096

void usage(const char *progname)
{
        fprintf(stderr, "usage: %s <hostname> <topic> [port] [username] [password] [client_id]\n", progname);
}

int main(int argc, char *argv[])
{
        struct mosquitto *mosq = NULL;
        const char *hostname = NULL;
        const char *topic = NULL;
        int port = 1883;
        const char *username = NULL;
        const char *password = NULL;
        const char *client_id = NULL;
        char buffer[BUFFER_SIZE] = {0};

        /* parse arguments */
        if (argc < 3) {
                usage(argv[0]);
                return EXIT_FAILURE;
        }

        hostname = argv[1];
        topic = argv[2];

        if (argc >= 4) {
                port = atoi(argv[3]);
        }

        if (argc >= 5) {
                username = argv[4];
        }

        if (argc >= 6) {
                password = argv[5];
        }

        if (argc >= 7) {
                client_id = argv[6];
        }

        /* initialize the mosquitto library */
        mosquitto_lib_init();

        /* create a new mosquitto client instance */
        mosq = mosquitto_new(client_id, true, NULL);
        if (mosq == NULL) {
                fprintf(stderr, "failed to create mosquitto instance\n");
                mosquitto_lib_cleanup();
                return EXIT_FAILURE;
        }

        /* set username and password if provided */
        if (username != NULL) {
                if (mosquitto_username_pw_set(mosq, username, password) != MOSQ_ERR_SUCCESS) {
                        fprintf(stderr, "failed to set username and password\n");
                        mosquitto_destroy(mosq);
                        mosquitto_lib_cleanup();
                        return EXIT_FAILURE;
                }
        }

        /* connect to the mqtt broker */
        if (mosquitto_connect(mosq, hostname, port, 60) != MOSQ_ERR_SUCCESS) {
                fprintf(stderr, "unable to connect to mqtt broker at %s:%d\n", hostname, port);
                mosquitto_destroy(mosq);
                mosquitto_lib_cleanup();
                return EXIT_FAILURE;
        }

        /* start the network loop in a separate thread */
        if (mosquitto_loop_start(mosq) != MOSQ_ERR_SUCCESS) {
                fprintf(stderr, "failed to start mosquitto loop\n");
                mosquitto_destroy(mosq);
                mosquitto_lib_cleanup();
                return EXIT_FAILURE;
        }

        /* read lines from stdin and publish each line */
        while (fgets(buffer, BUFFER_SIZE, stdin) != NULL) {
                size_t len = strlen(buffer);

                /* strip newline if present */
                if (len > 0 && (buffer[len - 1] == '\n' || buffer[len - 1] == '\r')) {
                        buffer[len - 1] = '\0';
                        len--;
                }

                if (len > 0) {
                        if (mosquitto_publish(mosq, NULL, topic, (int)len, buffer, 0, false) != MOSQ_ERR_SUCCESS) {
                                fprintf(stderr, "failed to publish message\n");
                        }
                }
                memset(buffer, 0, sizeof(buffer));
        }

        /* cleanup and disconnect */
        mosquitto_loop_stop(mosq, true);
        mosquitto_disconnect(mosq);
        mosquitto_destroy(mosq);
        mosquitto_lib_cleanup();

        return EXIT_SUCCESS;
}
