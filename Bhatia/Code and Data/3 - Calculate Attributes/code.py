#READ ME
#This code uses cosine similarity between reason and attribute vectors to represent each reddit post as a list of attribute vectors corresponding to costs and benefits for each of the two choice options
#The output for each subreddit is "output - subreddit.csv"

#=========================================
#LOAD MODULES AND SPECIFY DIRECTORY

import pandas, os, numpy, string, pickle, random
from sklearn.metrics.pairwise import cosine_similarity

#specify directory
directory = "...//3 - Calculate Attributes"
os.chdir(directory)

#specify subreddit
subreddit = 'Advice'

#=========================================
#COMBINE REASON DICTIONARIES FOR INDIVIDUAL CHUNKS OF SUBREDDIT DATA FROM STEP 1

#function
def merge_dicts(dict1, dict2):
    result = dict1.copy()
    result.update(dict2)
    return result
    
#specify path (this is path to step 2 outputs of the pipeline)
folder_path = '...//2 - Vectorize Reasons//Downloads//' + subreddit

#iterate overfiles and put in a merged dictionary
merged_dict = {}
for filename in os.listdir(folder_path):
    if filename.endswith('.pkl'):
        file_path = os.path.join(folder_path, filename)
        try:
            with open(file_path, 'rb') as file:
                data = pickle.load(file)
            merged_dict = merge_dicts(merged_dict, data)
        except Exception as e:
            print(f"Error loading {file_path}: {e}")
print("dictionary merged")

#====================================
#CODE REASONS ON ATTRIBUTES

#load coded posts
df = pandas.read_csv("...//1 - Code Posts//" + "data - " + subreddit + ".csv")

#load attributes dictionary
with open('...//2 - Vectorize Reasons//Downloads//output - attributesdict.pkl', 'rb') as file:
    attributesdict = pickle.load(file)
    
#separate attributes into pros and cons in their own dictionaries, and also extract attribute names
names = []
prosdict = {}
consdict = {}
for attribute in attributesdict.keys():
    if attribute.split('_')[1] == "pro":
        names.append(attribute.split('_')[0])
        prosdict[attribute.split('_ ')[0]] = attributesdict[attribute]
    elif attribute.split('_')[1] == "con":
        consdict[attribute.split('_ ')[0]] = attributesdict[attribute]
prosvec = numpy.array(list(prosdict.values()))
consvec = numpy.array(list(consdict.values()))

#iterate through posts and calculate the similarity of the associated reason vectors with our attribute vectors
output1 = [[]]
output2 = [[]]
for index,row in df.iterrows():
    
    #print
    if index%100 == 0:
        print(index,"row completed")
        
    #iterate through options in the post
    for opt in ['1','2']:
    
        #iterate through costs and benefits
        for s in ['benefits','costs']:
        
            #iterate over the three reasons    
            for r in ['1','2','3']:
                
                #extract reason
                reason = row[s+opt+'_'+r]
            
                #if not nan then code it:
                if isinstance(reason,str):
                    
                    #extract reason vector from reason dictionary 
                    rvec = merged_dict[reason].reshape(1,768)   
                    
                    #calculate  its similarity with attribute pros or cons 
                    if s == 'benefits':
                        sim = cosine_similarity(rvec,prosvec)
                    elif s == 'costs':
                        sim = cosine_similarity(rvec,consvec)
                        
                    #same similarity as well as reason metadata
                    output1.append(list(sim[0]))
                    output2.append([reason,s,r])
                
#put into pandas df
df_reasons = pandas.DataFrame(output1[1:],columns = names)

#subtract mean to normalize
df_reasons = df_reasons.sub(df_reasons.mean(axis=1), axis=0)

#combine with metadata into reason vector dataframe df_reasons
df_reasons2 = pandas.DataFrame(output2[1:],columns = 'reason,s,r'.split(','))
for c in 'reason,s,r'.split(','):
    df_reasons[c] = df_reasons2[c]
print("reasons dataframe generated")

#see highest coded for random sample
df_reasons_ben = df_reasons[df_reasons['s'] == 'benefits']
df_reasons_cos = df_reasons[df_reasons['s'] == 'costs']
for a in random.sample(names,1):
    print(a,' --- ',df_reasons_ben.loc[df_reasons_ben[a].idxmax(), 'reason'])
    print("**")
    print(a,' --- ',df_reasons_cos.loc[df_reasons_cos[a].idxmax(), 'reason'])

#put into dictionary
reasondict_attributes = {}
for i in range(1,len(output1)):
    dictkey = output2[i][0]
    dictval = output1[i]
    reasondict_attributes[dictkey] = dictval
print("reason attribute dictionary generated")

#====================================
#MERGE ATTRIBUTES INTO CHOICES AND SAVE

output = [[]]
#iterate through posts
for i, row in df.iterrows():

    #print
    if i%1000 == 0:
        print(i,"row completed")
        
    #empty list for the choice problem
    choice_vec = []
    
    #variable to keep track if there is nan
    code = 1
    
    #iterate through choice options
    for opt in ['1','2']:
    
            #iterate through costs and benefits
            for s in ['benefits','costs']:
            
                #empty list for the reason type
                rvec_all = [[]]
                
                #iterate through the three reasons and and append
                for r in ['1','2','3']:
                    reason = row[s+opt+'_'+r]
                    
                    #if not nan then get its attribute values 
                    if isinstance(reason,str):
                        #rvec = list(df_reasons[df_reasons['reason'] == reason][attributelist].values[0])
                        rvec = reasondict_attributes[reason]
                        rvec_all.append(rvec)
                
                #average the three reasons (and if all three had nan don't code)
                if len(rvec_all) > 1:
                    rvec_all=numpy.array(rvec_all[1:])
                    rvec_all = list(numpy.mean(rvec_all,axis=0))
                else:
                    code = 0
                    
                #concatenate to choice vector
                choice_vec = choice_vec + rvec_all
     
    #only append if there were no nan           
    if code == 1:
        output.append(list(row) + choice_vec)

#put into pandas df
columnnames = list(df.columns) + ['choice1_benefits' + str(i) for i in range(1, len(rvec_all) + 1)] + ['choice1_costs' + str(i) for i in range(1, len(rvec_all) + 1)] + ['choice2_benefits' + str(i) for i in range(1, len(rvec_all) + 1)] + ['choice2_costs' + str(i) for i in range(1, len(rvec_all) + 1)]
df_final = pandas.DataFrame(output[1:],columns = columnnames)                

#save
df_final.to_csv('output - ' + subreddit + '.csv')
print("final df has length", len(df_final))
