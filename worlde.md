word = "paris"

while True:
    count = 0
    user = input("\nEnter a word: ").lower()
    if len(user) == 5:
        for e in range(len(word)):
                if user[e] == word[e]:
                    print("✅", end = " ")
                    count += 1
                elif user[e] in word:
                    print( "🟡", end = " ")
                else:
                    print("❌ ", end = " ")
        if count == 5:
            print("Has adivinado la palabra")
            break
    else:
        print("The word must be of 5 characters")
