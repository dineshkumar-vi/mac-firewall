import shlex
import subprocess

# Make sure that cURL has Silent mode (--silent) activated
# otherwise we receive progress data inside err message later

def exec():
    cURL = r"""curl --unix-socket /var/run/docker.sock http://localhost/v1.40/containers/json"""
    lCmd = shlex.split(cURL)  # Splits cURL into an array
    p = subprocess.Popen(lCmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = p.communicate()  # Get the output and the err message
    return out.decode("utf-8")




