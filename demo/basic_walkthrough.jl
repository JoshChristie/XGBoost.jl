using XGBoost

# In this example, we will predict whether a mushroom is safe to eat.

# Load the agaricus dataset using the readlibsvm helper function.
function readlibsvm(fname::ASCIIString, shape)
    dmx = zeros(Float32, shape)
    label = Float32[]
    fi = open(fname, "r")
    cnt = 1
    for line in eachline(fi)
        line = split(line, " ")
        push!(label, float(line[1]))
        line = line[2:end]
        for itm in line
            itm = split(itm, ":")
            dmx[cnt, Int(itm[1]) + 1] = float(Int(itm[2]))
        end
        cnt += 1
    end
    close(fi)
    return (dmx, label)
end

train_X, train_Y = readlibsvm(Pkg.dir("XGBoost") * "/data/agaricus.txt.train", (6513, 126))
test_X, test_Y = readlibsvm(Pkg.dir("XGBoost") * "/data/agaricus.txt.test", (1611, 126))

#-------------Basic Training using XGBoost-----------------
# Note: xgboost naturally handles sparse input.
# Use sparse matrix when your features are sparse (e.g. when using one-hot encoding).
# Model parameters can be set as parameters for the `xgboost` function, or with a Dict.
num_round = 2

print("training xgboost with dense matrix\n")
# you can directly pass Julia's matrix or sparse matrix as data,
# by calling xgboost(data, num_round, label=label, training-parameters)
bst = xgboost(train_X, num_round, label = train_Y, eta = 1, max_depth = 2,
              objective = "binary:logistic")


print("training xgboost with sparse matrix\n")
sptrain = sparse(train_X)
# alternatively, you can pass parameters in as a map
param = ["max_depth" => 2,
         "eta" => 1,
         "objective" => "binary:logistic"]
bst = xgboost(sptrain, num_round, label = train_Y, param = param)

# you can also put in xgboost's DMatrix object
# DMatrix stores label, data and other meta datas needed for advanced features
print("training xgboost with DMatrix\n")
dtrain = DMatrix(train_X, label = train_Y)
bst = xgboost(dtrain, num_round, eta = 1, objective = "binary:logistic")

#--------------------basic prediction using XGBoost--------------
# you can do prediction using the following line
# you can put in Matrix, SparseMatrix or DMatrix
preds = predict(bst, DMatrix(test_X))
print("test-error=", sum((preds .> .5) .!= test_Y) / float(length(preds)), "\n")

#-------------------save and load models-------------------------
# save model to binary local file
save_model(bst, "xgb.model")
# load binary model to julia
bst2 = Booster(model_file = "xgb.model")
preds2 = predict(bst2, DMatrix(test_X))
print("sum(abs.(pred2 .- pred))=", sum(abs.(preds2 .- preds)), "\n")

#----------------Advanced features --------------
# to use advanced features, we need to put data in xgb.DMatrix
dtrain = DMatrix(train_X, label = train_Y)
dtest = DMatrix(test_X, label = test_Y)

#---------------Using watchlist----------------
# watchlist is a list of DMatrix, each of them tagged with name
# DMatrix in watchlist should have label (for evaluation)
watchlist  = [(dtest, "eval"), (dtrain, "train")]
# we can change evaluation metrics, or use multiple evaluation metrics
bst = xgboost(dtrain, num_round, param = param, watchlist = watchlist,
              metrics = ["logloss", "error"])

# we can also save DMatrix into binary file, then we can load it faster next time
save_binary(dtest, "dtest.buffer")
save_binary(dtrain, "dtrain.buffer")

# load model and data
dtrain = DMatrix("dtrain.buffer")
dtest = DMatrix("dtest.buffer")
bst = Booster(model_file = "xgb.model")

# information can be extracted from DMatrix using the get_ functions
label = get_label(dtest)
pred = predict(bst, dtest)
print("test-error=", sum((pred .> .5) .!= label) / float(length(pred)), "\n")

# Finally, you can dump the tree you learned using dump_model into a text file
dump_model(bst, "dump.raw.txt")
# If you have feature map file, you can dump the model in a more readable way
dump_model(bst, "dump.nice.txt", fmap = Pkg.dir("XGBoost") * "/data/featmap.txt")
