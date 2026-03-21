word = "paris"
max_intentos = 5
intentos = 0

while intentos < max_intentos:
    user = input("\nEnter a 5-letter word: ").lower().strip()

    if len(user) != len(word):
        print("The word must be 5 characters")
        continue  # no cuenta como intento

    intentos += 1
    count = 0

    for i in range(len(word)):
        if user[i] == word[i]:
            print("✅", end=" ")
            count += 1
        elif user[i] in word:
            print("🟡", end=" ")
        else:
            print("❌", end=" ")

    print()  # salto de línea

    if count == len(word):
        print("You have guessed the word!!!")
        break

else:
    print("\nYou have run out of attempts")
