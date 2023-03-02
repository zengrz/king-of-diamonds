# king-of-diamonds

![king-of-diamonds](https://cdn.shopify.com/s/files/1/0250/6696/3049/products/king-of-diamonds-neon-sign-neonspace-363132_1800x1800.jpg?v=1634744939)

King of Diamonds is a mult-player, number-guessing game. The rules of the game is as follow:

1. Each player submit a integer number between 0-100 inclusive. 
2. Take the average of the values and multiply by 0.8 to get `x`. Player with guess closest to the value `x` wins. 

The above constitutes one round. Each player starts with 0 points, player with -10 points is eliminated. A new rule is introduced with each eliminated player. 

To make the best approximation, each player has to anticipate guesses of the other players. The game is based on Keynesian Beauty Contest and has applications in trading. 

Visit https://aliceinborderland.link/ for latest.

## Protocol

Since guess are submitted on a blockchain, the guesses can be extracted by any thirdparty from the blockchain, making the game unfair potentially. To resolve this, we need to:

1. Server generates a public-private key. Public key is available to for all (new) users.
2. For each new user, generate a new public-private key pair. Encrypt the newly generated public key with the public key from server and send the encrypted public key to server on blockchain. This ensures no thirdparty knows the new public key of the user. The server would then get the decrypted public key of each user.
3. When a user submits a guess, encrypt the guess with his/her private key and send to server the encrypted key on blockchain. This ensures that each encrypted guess is unique for every user.
4. The server can then decrypt the guess with the public key of the corresponding user.
