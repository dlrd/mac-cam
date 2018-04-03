#include "renderers/gl-test-renderer.h"

GLFWwindow* window = nullptr;
GLTestRenderer renderer;

static void error_callback(int error, const char* description)
{
    fprintf(stderr, "Error: %s\n", description);
}

static void key_callback(GLFWwindow* window, int key, int scancode, int action, int mods)
{
    if (key == GLFW_KEY_ESCAPE && action == GLFW_PRESS)
        glfwSetWindowShouldClose(window, GL_TRUE);
}

static void resize_callback(GLFWwindow* window, int w, int h)
{
    renderer.resize(w, h);
}

int
main (int argc, const char* argv[])
{
    glfwSetErrorCallback(error_callback);

    if (!glfwInit())
        exit(EXIT_FAILURE);

    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 2);

    window = glfwCreateWindow(640, 480, "GL App", NULL, NULL);

    if (!window)
    {
        glfwTerminate();
        exit(EXIT_FAILURE);
    }

    glfwSetKeyCallback(window, key_callback);
    glfwSetFramebufferSizeCallback(window, resize_callback);

    glfwMakeContextCurrent(window);
    glfwSwapInterval(1);

    renderer.initWithDefaultFBO(0);

    while (!glfwWindowShouldClose(window))
    {
        // float ratio;
        // int width, height;

        // glfwGetFramebufferSize(window, &width, &height);
        // ratio = width / (float) height;

        // glViewport(0, 0, width, height);
        // glClear(GL_COLOR_BUFFER_BIT);

        renderer.renderForTime(0);

        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    glfwDestroyWindow(window);

    glfwTerminate();
    exit(EXIT_SUCCESS);
}
