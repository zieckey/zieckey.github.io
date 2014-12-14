---
layout: home
---

<div class="index-content opinion">

    <div class="section">

        <div class="cate-bar"><span id="cateBar"></span></div>

        <ul class="artical-list">
        {% for tag in site.tags %}
            <li>
             	<h2 id="{{ tag[0] }}-ref">
	                    {{ tag[0] }}
	             </h2>
	             	{% assign pages_list = tag[1] %}
            			{% for post in pages_list %}
	                	<div class="title-desc">{{post.title}}</div>
        				{% endfor %}
            </li>
        {% endfor %}
        </ul>
    </div>
    <div class="aside">
    </div>
</div>
