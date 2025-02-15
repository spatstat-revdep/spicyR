#' Plots result of signifPlot.
#'
#' @param results Data frame obtained from spicy.
#' @param type Where to make a bubble plot or heatmap.
#' @param fdr TRUE if FDR correction is used.
#' @param breaks Vector of 3 numbers giving breaks used in pheatmap. The first 
#' number is the minimum, the second is the maximum, the third is the number of breaks.
#' @param colours Vector of colours to use in pheatmap.
#' @param marksToPlot Vector of marks to include in pheatmap.
#' @param cutoff significance threshold for circles in bubble plot
#'
#' @return a pheatmap object
#'
#' @examples
#' data(spicyTest)
#' signifPlot(spicyTest, breaks=c(-3, 3, 0.5))
#' 
#' @export
#' @importFrom pheatmap pheatmap
#' @importFrom grDevices colorRampPalette
#' @importFrom stats p.adjust
#' @importFrom ggplot2 ggplot scale_colour_gradient2 geom_point scale_shape_manual guides labs scale_color_manual theme_classic theme element_text aes guide_legend element_blank guide_colourbar
#' @importFrom ggforce geom_arc_bar geom_circle
#' @importFrom grDevices colors
signifPlot <- function(results,
                       fdr = FALSE,
                       type = "bubble",
                       breaks = NULL,
                       colours = c("#4575B4", "white", "#D73027"),
                       marksToPlot = NULL,
                       cutoff = 0.05) {
    
     
    marks <- unique(results$comparisons$from)
    if (is.null(marksToPlot)) marksToPlot <- marks
    
    if(type == "bubble"){
       return(bubblePlot(results, fdr, breaks,  colours = colours, cutoff = cutoff, marksToPlot = marks))
            
    }
    
    if(is.null(breaks)) breaks <- c(-3,3,0.5)
    breaks <- seq(from = breaks[1], to = breaks[2], by = breaks[3])
    pal <- colorRampPalette(colours)(length(breaks))
    
    
    pVal <- results$p.value[,2]
    
    if (min(pVal,na.rm=TRUE) == 0) {
        pVal[pVal == 0] <-
            pVal[pVal == 0] + 10 ^ floor(log10(min(pVal[pVal > 0],na.rm = TRUE)))
    }
    
    if (fdr) {
        pVal <- p.adjust(pVal, method = "fdr")
    }
    
    isGreater <- results$coefficient[,2] > 0
    
    pVal <- log10(pVal)
    
    pVal[isGreater] <- abs(pVal[isGreater])
    
    pVal <- matrix(pVal, nrow = length(marks))
    colnames(pVal) <- marks
    rownames(pVal) <- marks
    
    

    
    heatmap <- pheatmap(
        pVal[marksToPlot, marksToPlot],
        color = pal,
        breaks = breaks,
        cluster_rows = FALSE,
        cluster_cols = FALSE
    )
    
    heatmap
}


bubblePlot <- function(test, fdr, breaks, colours = c("blue", "white", "red"), cutoff = 0.05, marksToPlot){

size <- -log10(test$p.value[,2])
groupA <- test$coefficient[,1]*sqrt(pi)*2/sqrt(10)/100
groupB <- (test$coefficient[,1] + test$coefficient[,2])*sqrt(pi)*2/sqrt(10)/100
cellTypeA <- factor(test$comparisons$from)
cellTypeB <- factor(test$comparisons$to)

sig <- test$p.value[,2] < cutoff
sigLab <- paste0("p-value < ",cutoff)
if(fdr){
sig <- test$p.value[,2] < cutoff   
sigLab <- paste0("fdr < ",cutoff)
}

df <- data.frame(cellTypeA, cellTypeB, groupA, groupB, size, stat = test$statistic[,2], pvalue = test$p.value[,2], sig = factor(sig))
rownames(df) <- rownames(test$statistic)

df <- df[df$cellTypeA%in% marksToPlot & df$cellTypeB%in% marksToPlot,]

shape.legend = c(GroupA = "\u25D6", GroupB = "\u25D7")

df.shape = data.frame(cellTypeA = c(NA,NA), cellTypeB = c(NA,NA), size = c(1,1), condition = c("GroupA", "GroupB"))


if(is.null(breaks)){
    limits <- c(floor(min(c(groupA,groupB), na.rm = TRUE)*2)/2, ceiling(max(c(groupA,groupB), na.rm = TRUE)*2)/2)
    by <- round((max(abs(c(groupA,groupB)), na.rm = TRUE)/2-0.01))/2
    breaks <- c(ceiling(min(c(groupA,groupB), na.rm = TRUE)*2)/2,floor(max(c(groupA,groupB), na.rm = TRUE)*2)/2,by)
    breaks <- c(floor(min(c(groupA,groupB), na.rm = TRUE)*2)/2,seq(from = breaks[1], to = breaks[2], by = breaks[3]),ceiling(max(c(groupA,groupB), na.rm = TRUE)*2)/2)
} else{
    limits <- c(breaks[1], breaks[2])
    breaks <- seq(from = breaks[1], to = breaks[2], by = breaks[3])
}
  
df$groupA <- pmax(pmin(df$groupA, limits[2]), limits[1])
df$groupB <- pmax(pmin(df$groupB, limits[2]), limits[1])  
  
pal <- colorRampPalette(colours)(length(breaks))
  
labels <- round(breaks,1)
labels[1] <- "avoidance"
labels[length(labels)] <- "attraction"

    ggplot2::ggplot(df, ggplot2::aes(x = cellTypeA, y = cellTypeB)) + 
    ggplot2::scale_fill_gradient2(low =colours[1], mid = colours[2], high = colours[3], midpoint = 0, breaks = breaks, labels = labels, limits = limits) +
    ggplot2::geom_point(aes(colour = sig), size = 0) + 
    ggplot2::geom_point(aes(size = size), x = 100000, y = 10000000) + 
    ggplot2::scale_color_manual(values = c("FALSE" = "white", "TRUE" = "black"), labels = c("", sigLab)) + 
    ggforce::geom_arc_bar(ggplot2::aes(fill = groupA, r = pmax(size/max(size, na.rm = TRUE)/2,0.15), r0 = 0, x0 = as.numeric(cellTypeA), y0 = as.numeric(cellTypeB), start = 0, end = pi, x = NULL, y = NULL),color = NA) + 
    ggforce::geom_arc_bar(ggplot2::aes(fill = groupB, r = pmax(size/max(size, na.rm = TRUE)/2, 0.15), r0 = 0, x0 = as.numeric(cellTypeA), y0 = as.numeric(cellTypeB), start = pi, end = 2*pi, x = NULL, y = NULL), colour = NA)+
    ggforce::geom_circle(data = df[df$sig=="TRUE",],aes(r = pmax(size/max(size, na.rm = TRUE)/2, 0.15), x0 = as.numeric(cellTypeA), y0 = as.numeric(cellTypeB), x = NULL, y = NULL), colour = "black") + 
    #ggplot2::geom_point(ggplot2::aes(colour = groupB), shape="\u25D1") + 
    ggplot2::geom_point(data= df.shape, ggplot2::aes(shape = condition), x = 10000, y = 10000)+ 
    ggplot2::scale_shape_manual(values = shape.legend) +
    ggplot2::theme_classic() + 
    ggplot2::theme( axis.text.x = ggplot2::element_text(angle = 90, hjust = 1, vjust = 0),
                    legend.box.background = ggplot2::element_blank()) +
    ggplot2::labs(x = "Cell type i", y = "Cell type j", size = "-log10 p-value", colour = NULL, fill = "Localisation", shape = "Condition") +
        guides(shape = ggplot2::guide_legend(order = 3, override.aes = list(size=5)),
               fill = ggplot2::guide_colourbar(order = 4),
               size = ggplot2::guide_legend(order = 2),
               colour = ggplot2::guide_legend(order = 1, override.aes = list(size=5, shape = 1))
               )
    
}
