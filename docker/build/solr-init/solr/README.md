# Custom Solr Cores

If you would like to include custom Solr cores in your build add a new within the _solr_ directory.

**Filename:** _cores-custom.json_ (can be named anything with the _json_ extension)

```json
{
    "sitecore": [
        "_sxa_company_master_index",
        "_sxa_company_master_index_rebuild",
        "_sxa_company_web_index",
        "_sxa_company_web_index_rebuild"
    ]    
}
```
