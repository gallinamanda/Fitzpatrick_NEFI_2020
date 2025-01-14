
path.hub <- "C:/Users/lucie/Documents/GitHub/NEFI/data/"

dat.npn <- read.csv(file.path(path.hub, file = "Arb_Quercus_NPN_data_leaves_CLEAN_individual.csv"), na.strings = "-9999")

#Daymet for when using covariates
dat.met <- read.csv(file.path(path.hub, file = "Daymet_data_raw.csv"))

#creating 2018 frame for hindcasting
dat.2018 <- dat.npn[dat.npn$year == 2018, ]

#isolating just 2019 year for our model
dat.npn <- dat.npn[dat.npn$year == 2019, ]

#Setting the start of possible fall color as starting August 1st
dat.npn <- dat.npn[dat.npn$day_of_year > 213, ]


dat.npn$color.full <- as.numeric(as.character(dat.npn$color.full))


library(rjags)
library(coda)


RandomWalk = "
model{
  
  #### Data Model
  for(i in 1:n){
    y[i] ~ dnorm(x[time[i]], tau_obs)

  }
  
  #### Process Model
  for(t in 2:nt){
    x[t]~dnorm(x[t-1],tau_add)
  }
  
  #### Priors
  x[1] ~ dnorm(x_ic,tau_ic)
  tau_obs ~ dgamma(a_obs,r_obs)
  tau_add ~ dgamma(a_add,r_add)
}
"


RandomWalk_binom = "
model{
  
  #### Data Model
  for(i in 1:n){
    y[i] ~ dbern(x[time[i]])
  }
  
  #### Process Model
  for(t in 2:nt){
    z[t]~dnorm(x[t-1],tau_add)
    x[t] <- min(0.999,max(0.0001,z[t]))
  }
  
  #### Priors
  x[1] ~ dnorm(x_ic,tau_ic)
  # tau_obs ~ dgamma(a_obs,r_obs)
  tau_add ~ dgamma(a_add,r_add)
}
"
data <- list(y = dat.npn$color.full, n = length(dat.npn$color.full), time = dat.npn$day_of_year-213, nt = 365-213, 
            a_add=1, r_add=1, x_ic = 0 , tau_ic = 1000)




j.model   <- jags.model (file = textConnection(RandomWalk_binom),
                         data = data,
                         n.chains = 3)

jags.out   <- coda.samples (model = j.model,
                            variable.names = c("x","tau_add"),
                            n.iter = 10000)


gelman.diag(jags.out)

#plot(jags.out)

#GBR <- gelman.plot(jags.out)

#burnin = 5000                                ## determine convergence
#jags.burn <- window(jags.out,start=burnin)  ## remove burn-in
#plot(jags.burn)                             ## check diagnostics post burn-in

out <- as.matrix(jags.out)
x.cols <- grep("^x",colnames(out)) ## grab all columns that start with the letter x
ci <- apply(out[,x.cols],2,quantile,c(0.025,0.5,0.975)) ## model was fit on log scale

time <- 214:365
plot(time,ci[2,],type='n',ylim=c(0,1),ylab="Fall color")
## adjust x-axis label to be monthly if zoomed
if(diff(time.rng) < 100){ 
  axis.Date(1, at=seq(time[time.rng[1]],time[time.rng[2]],by='month'), format = "%Y-%m")
}
ecoforecastR::ciEnvelope(time,ci[1,],ci[3,],col=ecoforecastR::col.alpha("lightBlue",0.75))
points(dat.npn$day_of_year, dat.npn$color.full ,pch="+",cex=0.5)


