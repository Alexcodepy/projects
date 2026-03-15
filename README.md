# Calcualdora

unidades = ["km", "cm", "m"]

print("\nCALULADORA COMPLETA")
print("===================")
print("1. Ecuación segundo grado\n2. Cambiar unidades\n3. Calculo velocidad\n4. Calcualdora sencilla\n5. SALIR")
print("===================\n")
usuario = int(input("- ¿Que opción eligues?: "))

try:
    if usuario == 1:
        a = float(input("Número 1: "))
        b = float(input("Número 2: "))
        c = float(input("Número 3: \n"))

        if a == 0:
            if b == 0:
                if c == 0:
                    print("ERROR DE CALCULO")
                else:
                    print("SIN SOLUCIÓN")
            else:
                solution = round(-c / b, 3)
                print(f"La única solución es {solution}")
        elif b == 0:
            if c == 0:
                print("La solución es 0")
            else:
                solution = round((-c / a) ** 0.5, 3)
                print(solution, "y", solution * (-1))
        else:
            discriminante = (b * b) - 4 * a * c
            if discriminante > 0:
                solution = round((-b + ((b * b) - 4 * a * c) ** 0.5) / (2 * a), 3)
                solution_2 = round((-b - ((b * b) - 4 * a * c) ** 0.5) / (2 * a), 3)
                print("Solucion 1:", solution, ",Solución 2:", solution_2)
            elif discriminante == 0:
                solution = round(-b / (2 * a), 3)
                print("Doble solución:", solution)
            else:
                print("¡¡¡Raiz negativa!!!")

    elif usuario == 2:
        print("Vamos a cambiar unidades")
        print("==============================================\n")

        choose = input("- ¿Que uidad deseas cambiar?: ").lower().strip()
        while choose not in unidades:
            print("Unidad no válida")
            choose = input("- ¿Que uidad deseas cambiar?: ").lower().strip()
            if choose == "salir" or choose == "4":
                exit()
        print("----------------------------------------------")
        distancia = int(input("- ¿Cuál es el número que desea cambiar?: "))

        if choose == "cm":
            if distancia >= 100000:
                km = distancia // 100000
                resto = distancia % 100000
                print(f"{km}km", end=" ")

                if resto >= 100:
                    m = resto // 100
                    rest = resto % 100
                    print(f"{m}m", end=" ")
                    
                    if rest != 0:
                        print(f"{rest}cm")
                else:
                    if resto != 0:
                        print(f"{resto}cm")

            else:
                if distancia >= 100:
                    m = distancia // 100
                    rest = distancia % 100
                    print(f"{m}m {rest}cm")
                else:
                    print(f"Es lo mismo: {distancia}cm")
        else:
            while True:
                if choose == "m":
                    print("1. A kilómetros\n2. A centrímetros")
                    pregunta = int(input("- ¿Prefieres 1 o 2?: "))
                    if pregunta == 1:
                        km = distancia / 1000
                        print(f"{distancia}m, son {km}km")
                        break
                    elif pregunta == 2:
                        cm = distancia * 100
                        print(f"{distancia}m son {cm}cm")
                        break
                    else:
                        print("Por favor, ingrese una opción válida")
                        
                else:
                    print("1. A metros\n2. A centrímetros")
                    pregunta = int(input("- ¿Prefieres 1 o 2?: "))
                    if pregunta == 1:
                        m = distancia * 1000
                        print(f"{distancia}km, son {m}m")
                        break
                    elif pregunta == 2:
                        cm = distancia * 100000
                        print(f"{distancia}km son {cm}cm")
                        break
                    else:
                        print("Por favor, ingrese una opción válida")
                    
    elif usuario == 3:
        tiempo = float(input("- ¿Cuanto tiempo ha tardado?: "))
        dis = float(input("- ¿Cuanta dsitancia ha recorido?: "))
        vel_lineal = dis / tiempo
        print("El objeto va a ", vel_lineal,"m/s")
        while True:
            ask = input("- ¿Quieres calcularlo en rad/s?: ").lower().strip()
            if ask == "si":
                ad = float(input("¿Cual es su radio?: "))
                ca = vel_lineal / ad
                print(f"\nEl objeto circular va a {ca}Rad/s")
                break
            elif ask == "no":
                print("Adiós, espero verte pronto")
                exit()
            else:
                print("-")
                print("Por favor, ingrese una opción válida")
                print("--------------------")

    elif usuario == 4:
        print("-")
        print("BIENVEIDO A LA CALCULADORA SIMPLE")
        print("Estas son nuestras operaciones:\nSuma, resta, divisón, multiplicación" )
        print("------------------------------")
        n1 = float(input("ingresa primer numero: "))
        n2 = float(input("ingresa segundo numero: "))
        op = input("- ¿Qué operacion prefieres?: ").lower().strip()
        if op == "suma":
            print(n1 + n2)
        elif op == "resta":
            print(n1- n2)
        else:
            if op == "división":
                print(n1 / n2)
            else:
                print(n1 * n2)

    elif usuario == 5:
        exit()        
    
    else:
        print("Se ha producido un error intentalo otra vez, opciones del 1 al 5")
                
except ValueError:
    print("Se ha prodicido un error de Valor no se aceptan carárteres")
