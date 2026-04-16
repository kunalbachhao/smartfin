#!/usr/bin/env python
# coding: utf-8
# In[1]:


import pandas as pd
import numpy as np  
import re


sms = "Rs 250 spent on your SBI Card at ZOMATO"

pattern = r"(Rs\.?\s?\d+).*?\b(spent|debited|paid|credited)\b"
        
if re.search(pattern, sms, re.IGNORECASE):
    # Extract Amount
    amount_match = re.search(r"(?:Rs\.?|INR)\s?([\d,]+)", sms, re.IGNORECASE)

    # Extract Merchant
    merchant_match = re.search(r"(?:at|to|in)\s([A-Z0-9&.\- ]+)", sms)

    if amount_match:
       amount = amount_match.group(1)

    if merchant_match:
       merchant = merchant_match.group(1).strip()

    print("Amount:", amount)
    print("Merchant:", merchant)
else:
    print("Not a Payment SMS")


merchant_category_map = {
    "ZOMATO": "Food",
    "SWIGGY": "Food",
    "DOMINOS": "Food",
    "UBER": "Travel",
    "OLA": "Travel",
    "IOCL": "Travel",
    "AMAZON": "Shopping",
    "FLIPKART": "Shopping",
    "NETFLIX": "Entertainment",
    "SPOTIFY": "Entertainment",
    "ELECTRICITY": "Bills",
    "WIFI": "Bills",
    "BYJUS": "Education",
    "UNACADEMY": "Education",
    "APOLLO": "Health",
    "MEDPLUS": "Health",
    "JIO": "Recharge",
    "AIRTEL": "Recharge"
}

category = merchant_category_map.get(merchant, "Unknown")
print("Category:", category)

from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.naive_bayes import MultinomialNB

# Load dataset
data = pd.read_csv("Expense_SMS_Dataset.csv")

# Features and labels
X = data["sms_text"].str.lower()
y = data["category"].str.lower()

# Convert text to numbers
vectorizer = TfidfVectorizer()
X_vec = vectorizer.fit_transform(X)

# Train model
model = MultinomialNB()
model.fit(X_vec, y)

print("Model trained successfully!...")

new_sms = ["Rs 350 paid at  "]

new_vec = vectorizer.transform(new_sms)
prediction = model.predict(new_vec)

print("Predicted Category:", prediction[0])

df = pd.read_csv("Teen_Spending_Dataset.csv" , nrows=209)


# In[7]:





# In[8]:


a=df.groupby(["date","category"])["amount"].sum()


# In[9]:


idx = a.index.get_level_values(1)


# In[10]:


edu = a[idx == "Education"].values
ent= a[idx == "Entertainment"].values
fod = a[idx == "Food"].values
reh = a[idx == "Recharge"].values
shop = a[idx == "Shopping"].values
trv = a[idx == "Travel"].values


# In[11]:


import matplotlib.pyplot as plt
x=[1,2,3,4,5,6,7]


# In[12]:


fod=np.array([2862, 1575, 1409, 2378,0, 1951, 2501])


# In[13]:


plt.stackplot(x , edu,ent,fod,reh,shop,trv ,
labels=['Education', 'Entertainment', 'Food', 'Recharge', 'Shopping', 'Travel'])
plt.legend()
plt.grid()


# In[14]:


idx = a.index.get_level_values(1)


# In[15]:


l = [edu,ent,fod,reh,shop,trv]
labels=['Education', 'Entertainment', 'Food', 'Recharge', 'Shopping', 'Travel']
fig,axs = plt.subplots(2,3)

for i in range(0,2):
    for j in range(0,3):
        index = 3*i + j;
        axs[i][j].bar(x , l[index])
        axs[i,j].grid(True)
        plt.tight_layout()
        axs[i,j].set_ylabel("Amount")
        axs[i,j].set_title(labels[index])




# In[16]:


def show_value(pct, all_vals):
    total = sum(all_vals)
    val = int(pct * total / 100)
    return f'₹{val}'
values = [edu.sum(),ent.sum(),fod.sum(),reh.sum(),shop.sum(),trv.sum()]    
plt.pie( values,labels=labels , autopct=lambda pct : show_value(pct,values))
plt.show()


# In[17]:


X_vec.shape


# In[18]:


from sklearn.linear_model import LogisticRegression
from sklearn.tree import DecisionTreeClassifier
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score


# In[19]:


clf1 = LogisticRegression(C=0.6)
clf2 = DecisionTreeClassifier(max_depth=6)
clf3 = RandomForestClassifier(max_depth=6 ,max_leaf_nodes=4)


# In[20]:


X_train, X_test, y_train, y_test = train_test_split(
    X_vec, y, test_size=0.2, random_state=42
)


# In[21]:


clf1.fit(X_train,y_train)
clf2.fit(X_train,y_train)
clf3.fit(X_train,y_train)


# In[22]:


clf1_pred = clf1.predict(X_test)
clf2_pred = clf2.predict(X_test)
clf3_pred = clf3.predict(X_test)

accuracy1 = accuracy_score(y_test, clf1_pred)
accuracy2 = accuracy_score(y_test, clf2_pred)
accuracy3 = accuracy_score(y_test, clf3_pred)


# In[23]:


print(f"LogisticRegression : {accuracy1}")
print(f"DecisionTreeClassifier : {accuracy2}")
print(f"RandomForestClassifier : {accuracy3}")


# In[24]:


from sklearn.tree import plot_tree
import matplotlib.pyplot as plt
plt.figure(figsize=(12,8))
plot_tree(clf2, filled=True)
plt.show()


# In[25]:


from sklearn.decomposition import PCA

pca = PCA(n_components=2)
X_train_2d = pca.fit_transform(X_train.toarray())


# In[28]:


plt.figure(figsize=(15,10))
plot_tree(clf3.estimators_[0], filled=True)
plt.show()


# In[31]:


df = pd.read_csv("final_data.csv")


# In[36]:


#function to remove special characters
def remove_special(text):
    x=""
    for i in text:
        if i.isalnum():
            x=x+i
        else:
            x=x+' '
    return x


# In[39]:


df["sms"] = df["sms"].apply(remove_special)


# In[48]:


from sklearn.feature_extraction.text import CountVectorizer
from sklearn.model_selection import train_test_split
cv = CountVectorizer(max_features=500)


# In[55]:


x = cv.fit_transform(df["sms"]).toarray()


# In[59]:


x_train , x_test , y_train , y_test = train_test_split(x,df["category"] ,test_size=0.2,random_state=42)

model1 = MultinomialNB()
model1.fit(x_train, y_train)

print("Model trained successfully!...")


# In[60]:


y_pred = model1.predict(x_test)


# In[61]:


accuracy_NB = accuracy_score(y_pred,y_test)


# In[62]:


accuracy_NB


# In[63]:


import joblib


# In[66]:


joblib.dump(model1,"model_NB.pkl")


# In[ ]:




