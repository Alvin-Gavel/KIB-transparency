The purpose of the code in this repository is for use by Karolinska Institutet (KI) in estimating open science indicators for articles. Given a list of PubMed Central IDs, it will download the articles and produce a dataframe containing the following columns:

`pmid`: The PubMed ID of the article

`pmcid`: The PubMed Central ID of the article

`research_article`: Whether the article is a research article

`review_article`: Whether the article is a review article

`open_data`: Whether the article links to openly accessible data

`open_code`: Whether the article links to openly accessible code

`coi_pred`: Whether the article states conflicts of interest

`fund_pred`: Whether the article discloses the source of funding

`register_pred`: Whether the research protocol is pre-registered

There are also functions for appending the dataframe to a SQL table.

It is important to note that while the code searches articles for claims about transparency, it cannot verify that any of the claims are *true*. It is entirely possible that an article that claims to provide access to data actually only contains a dead link.

`KI-transparent` makes use of the `rtransparent` library by Stylianos Serghiou, which can be found in the repository https://github.com/serghiou/rtransparent and is described in more detail in https://doi.org/10.1371/journal.pbio.3001107. `rTransparent` in turn makes use of `ODDPub`, which can be found in the repository https://github.com/quest-bih/oddpub and is described in more detail in http://doi.org/10.5334/dsj-2020-042.

Both `KI-transparent` itself and `rtransparent` also use a number of other R libraries. Most can be installed simply through `packages.install(library name)`, but specifically `crminer` can be slightly hard to get hold of. As of December 2nd 2022, the package has been taken down from CRAN, but the most recent version can still be downloaded from the archive.

`KI-transparent` is based on code written by Emmanuel Zavalis, which can be be found in the repository https://github.com/zavalis/autotransparent.