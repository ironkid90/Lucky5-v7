# main.py
from dotenv import load_dotenv
load_dotenv()
from e2b_code_interpreter import Sandbox

sbx = Sandbox.create() # Creates a persistent sandbox session
execution = sbx.run_code("print('hello world')") # Execute Python inside the sandbox
print(execution.logs)

files = sbx.files.list("/")
print(files)