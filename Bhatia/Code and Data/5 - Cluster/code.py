#READ ME
#This code performs heirarchical clustering on attributes and appends cluster labels for each post to previous output files
#Output is saved as "Output - subreddit - RDC.csv" with C corresponding to clusters
#Other outputs are dendograms 

#=========================================
#IMPORTS, SPECIFY DIRECTORY, AND LOAD FILE

import pandas, os, ast, numpy
import matplotlib.pyplot as plt
from datetime import datetime
from sklearn.cluster import KMeans
from kneed import KneeLocator
from scipy.cluster.hierarchy import dendrogram, linkage, fcluster

directory = '...//5 - Cluster'
os.chdir(directory)

#load coded posts from step 4 of pipeline
subreddit = 'Advice'
df = pandas.read_csv("... output - " + subreddit + " - RD.csv" )

#specify attribute names
attributelist = "gains vs. losses,safety vs. risk,immediacy vs. delay,altruism and morality,complexity and effort,money,social,health,mood,pleasure,existential concerns,career,personal development,romance,knowledge,laws and institutions,utilitarian consumption,hedonic consumption,material consumption,experiential consumption,valence,arousal,anger,fear,happiness,disgust,autonomy,competence,social relatedness,self direction,stimulation,hedonism,achievement,power,security,conformity,tradition,benevolence,universalism,achieving salvation,appreciating the arts,achieving my aspirations,sexual desirability,avoiding failure,avoiding feelings of guilt,avoiding rejection by others,avoiding stress,being able to fantasize,being affectionate toward others,being ambitious,being better than others,being lighthearted,being clean,maintaining conventional views,being creative,being curious,being disciplined,having freedom,being good looking,being honest,being in love,changing my ways,being intelligent,being likeable,being logical,being really passionate ,being playful,being in the center of things,being practical,keeping to myself,being admired,being reflective,being respected by others,being responsible,being independent,being socially attractive,being spontaneous,being unique,belonging to social groups,being able to meet my financial needs,buying things i want,being taken care of,having a career,keeping up to date with career-related knowledge,being committed to a cause,being charitable,being close to my children,being close to my spouse,being happy,making a lasting contribution to society,being in control of the environment,having control over others,being in a position to make decisions for others,defending myself against others’ criticisms or attacks,having enough money to leave for my descendants,having new and different experiences,accomplishing difficult things,having an easy and comfortable life,getting an education,obtaining an advanced educational degree,amusing others,having an erotic relationship,being an ethical person,having an exciting life,being physically active,seeking new things,keeping up with fashion,feeling close to my parents,having emotional intimacy,feeling safe and secure,finding higher meaning in life,having firm values,having flexibility of viewpoint,having freedom of choice,having a good marriage,being a good parent,having friends i love,receiving help from my parents,helping others,devoting time to amusements,having intellectual experiences,having a job i really like,knowing and being on familiar terms with many others,knowing myself,being a leader,learning more about art,accepting life’s limitations,living close to my parents,carrying myself well,looking physically fit,looking young,having a mature romantic relationship,having a mature understanding of life,having mechanical ability,being mentally healthy,having a mentor,making a lot of money,having original ideas,being physiologically healthy,having others to rely on,having others’ trust,overcoming failure,setting and following my own guidelines,having peace of mind,experiencing personal growth,influencing others,having physical ability,being in good physical condition,pleasing god,providing my family with financial security,pursuing my ideals,maintaining religious faith,engaging in religious traditions,having a rich social life,having romantic experiences,being involved in seeking equality,seeking fairness,seeking justice,having high self-esteem,setting good examples,enjoying sexual experiences,sharing feelings with close friends,having stability in life,having a stable family life,standing up for my beliefs,receiving support from others on projects i believe in,taking care of my parents and siblings,not being fearful,developing others,keeping things in order,being able to think intellectually,protecting my wellbeing,having wisdom,experiencing a world of beauty,harm,fairness,ingroup morality,authority,purity,character perception,personality perception,ability perception,goodness perception,morality perception,strength perception,grit perception,agency perception,communion perception,warmth perception,pleasure-based consumption,functional consumption,altruism,individualism,prosociality,competitiveness,efficiency,equality,personal connection,altruism at scale,tractability,altruism neglectedness,human wellbeing,non-human animal welfare,achieving a better future,procedural fairness,distributive fairness,reciprocal fairness".split(',')

#=========================================
#CLEAN UP DATA

#get rid of unnamed inde columns
df = df.loc[:, ~df.columns.str.contains('^Unnamed')]

#seprate into costs and benefits of two choice optoins
X1b = df[['choice1_benefits' + str(i) for i in range(1,len(attributelist)+1)]].values
X1c = df[['choice1_costs' + str(i) for i in range(1,len(attributelist)+1)]].values
X2b = df[['choice2_benefits' + str(i) for i in range(1,len(attributelist)+1)]].values
X2c = df[['choice2_costs' + str(i) for i in range(1,len(attributelist)+1)]].values

#subtract columns to get benefits mninus costs
X1 = numpy.zeros(X1b.shape)
for i in range(X1b.shape[1]):
    X1[:, i] = X1b[:, i] - X1c[:, i]
X2 = numpy.zeros(X2b.shape)
for i in range(X2b.shape[1]):
    X2[:, i] = X2b[:, i] - X2c[:, i]
X = numpy.vstack((X1, X2))
    
#=========================================
#HEIRARCHICAL CLUSTERING

#get linkages
data = X.T
labels = attributelist
Z = linkage(data, 'ward')

#specify cluster level
level = 40  

#plot and save dendogram
plt.figure(figsize=(8, 40))
dendro = dendrogram(Z, labels=labels, leaf_font_size=12, color_threshold=level, orientation = 'right')
plt.savefig('dendrogram.png', bbox_inches='tight',dpi=300)
plt.show()

#save horizontal version to edit
plt.figure(figsize=(20,8))
dendro = dendrogram(Z, labels=labels, leaf_font_size=12, color_threshold=level)
plt.savefig('dendrogram - horizontal.png', bbox_inches='tight',dpi=300)
plt.show()

#print clusters
column_labels = fcluster(Z, level, criterion='distance')
labels_and_names = list(zip(column_labels, attributelist))
for c in set(column_labels):
    print(c)
    print(' ')
    for i in range(0,len(labels_and_names)):
        label, name = labels_and_names[i]
        if label == c:
            print(name)
    print("================")
    
#=========================================
#CODE ORIGINAL POSTS ON CLUSTERS

#iterate over df and save
output = [[]]
for i, row in df.iterrows():
    
    #seprate into costs and benefits of two choice optoins
    x1b = row[['choice1_benefits' + str(i) for i in range(1,len(attributelist)+1)]].values
    x1c = row[['choice1_costs' + str(i) for i in range(1,len(attributelist)+1)]].values
    x2b = row[['choice2_benefits' + str(i) for i in range(1,len(attributelist)+1)]].values
    x2c = row[['choice2_costs' + str(i) for i in range(1,len(attributelist)+1)]].values
    
    #subtract columns to get benefits mninus costs
    x1= x1b - x1c
    x2= x2b - x2c
    
    #calculate average value on attributes in each cluster for optoin 1
    averages = []
    for label in set(column_labels):
        indices = numpy.where(column_labels == label)[0]
        avg = numpy.mean(x1[indices])
        averages.append(avg)
    
    #now option 2
    for label in set(column_labels):
        indices = numpy.where(column_labels == label)[0]
        avg = numpy.mean(x2[indices])
        averages.append(avg)
        
    #now option 1 benefits
    for label in set(column_labels):
        indices = numpy.where(column_labels == label)[0]
        avg = numpy.mean(x1b[indices])
        averages.append(avg)
    
    #now option 1 costs
    for label in set(column_labels):
        indices = numpy.where(column_labels == label)[0]
        avg = numpy.mean(x1c[indices])
        averages.append(avg)

     #now option 2 benefits
    for label in set(column_labels):
        indices = numpy.where(column_labels == label)[0]
        avg = numpy.mean(x2b[indices])
        averages.append(avg)
     
    #now option 2 costs
    for label in set(column_labels):
        indices = numpy.where(column_labels == label)[0]
        avg = numpy.mean(x2c[indices])
        averages.append(avg)
       
    #append
    output.append(averages)

    #print progress
    if len(output)%1000 == 0:
        print(len(output))

#concatenate to original dataframe and save
dfc = pandas.DataFrame(output[1:],columns = ["choice1_cluster" + str(i) for i in set(column_labels)] +  ["choice2_cluster" + str(i) for i in set(column_labels)] + ["choice1b_cluster" + str(i) for i in set(column_labels)] + ["choice1c_cluster" + str(i) for i in set(column_labels)] +  ["choice2b_cluster" + str(i) for i in set(column_labels)] +  ["choice2c_cluster" + str(i) for i in set(column_labels)]   )
df = pandas.concat([df,dfc],axis = 1)
df.to_csv('output - Advice - RDC.csv')
                                        
#=========================================
#CODE ADDITIONAL SUBREDDITS ON THESE CLUSTERS

#specify and load subreddit from step 4 of pipeline
for subreddit in 'careeradvice,FriendshipAdvice,AskMenAdvice,askwomenadvice'.split(','):
    df2 = pandas.read_csv("output - " + subreddit + " - RD.csv" )
        
    #iterate over df2 and save
    output = [[]]
    for i, row in df2.iterrows():
        
        #seprate into costs and benefits of two choice optoins
        x1b = row[['choice1_benefits' + str(i) for i in range(1,len(attributelist)+1)]].values
        x1c = row[['choice1_costs' + str(i) for i in range(1,len(attributelist)+1)]].values
        x2b = row[['choice2_benefits' + str(i) for i in range(1,len(attributelist)+1)]].values
        x2c = row[['choice2_costs' + str(i) for i in range(1,len(attributelist)+1)]].values
        
        #subtract columns to get benefits mninus costs
        x1= x1b - x1c
        x2= x2b - x2c
        
        #calculate average value on attributes in each cluster for optoin 1
        averages = []
        for label in set(column_labels):
            indices = numpy.where(column_labels == label)[0]
            avg = numpy.mean(x1[indices])
            averages.append(avg)
        
        #now option 2
        for label in set(column_labels):
            indices = numpy.where(column_labels == label)[0]
            avg = numpy.mean(x2[indices])
            averages.append(avg)
       
        #now option 1 benefits
        for label in set(column_labels):
            indices = numpy.where(column_labels == label)[0]
            avg = numpy.mean(x1b[indices])
            averages.append(avg)
        
        #now option 1 costs
        for label in set(column_labels):
            indices = numpy.where(column_labels == label)[0]
            avg = numpy.mean(x1c[indices])
            averages.append(avg)

         #now option 2 benefits
        for label in set(column_labels):
            indices = numpy.where(column_labels == label)[0]
            avg = numpy.mean(x2b[indices])
            averages.append(avg)
         
        #now option 2 costs
        for label in set(column_labels):
            indices = numpy.where(column_labels == label)[0]
            avg = numpy.mean(x2c[indices])
            averages.append(avg)
            
        #append
        output.append(averages)
    
        #print progress
        if len(output)%1000 == 0:
            print(len(output))
    
    #concatenate to original dataframe and save
    df2c = pandas.DataFrame(output[1:],columns = ["choice1_cluster" + str(i) for i in set(column_labels)] +  ["choice2_cluster" + str(i) for i in set(column_labels)] + ["choice1b_cluster" + str(i) for i in set(column_labels)] + ["choice1c_cluster" + str(i) for i in set(column_labels)] +  ["choice2b_cluster" + str(i) for i in set(column_labels)] +  ["choice2c_cluster" + str(i) for i in set(column_labels)]   )

    df2 = pandas.concat([df2,df2c],axis = 1)
    df2.to_csv('output - ' + subreddit + ' - RDC.csv')
                                           
    