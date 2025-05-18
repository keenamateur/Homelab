## Python
# sudo apt install -y python3 python3-pip  
# pip install bcrypt  

## wg_hash_generator.py

import bcrypt

password = input("Enter your Password: ").encode('utf-8')
salt = bcrypt.gensalt(rounds=12, prefix=b'2a')
hashed = bcrypt.hashpw(password, salt)
print("Hashed password (bcrypt):", hashed.decode('utf-8'))
