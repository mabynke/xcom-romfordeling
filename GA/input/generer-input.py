
index = 0
for i in range(15):
    for j in range(i):
         l = list(range(index, index+i))
         del l[j]
         print(" ".join([str(i+1) for i in l]))
    index += i
