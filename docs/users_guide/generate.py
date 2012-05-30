
import inspect
import os


class Inspect(object):
    """An inspector for a given module"""

    module_header = """:mod:`%(module)s`
===================================

.. automodule:: %(module)s

.. inheritance-diagram: GPS    # DISABLED, add "::" to enable

"""

    functions_header = """
Functions
---------

"""

    function_stub = ".. autofunction:: %(name)s\n"

    classes_header = """
Classes
-------

"""
    class_stub = """
:class:`%(module)s.%(name)s`
%(underscore)s

.. autoclass:: %(name)s

   %(inheritance)s
"""

    method_stub = """
   .. automethod:: %(name)s
"""

    data_stub = """

   .. autoattribute:: %(name)s

"""

    exceptions_header = """
Exceptions
-------

"""

    def __init__(self, module):
        self.module = module
        self.func = []
        self.classes = []
        self.excepts = []

        for obj_name, obj in module.__dict__.iteritems():
            if obj_name.startswith('__') \
               and obj_name not in ["__init__"]:
                pass
            elif inspect.ismodule(obj):
                pass
            elif inspect.isfunction(obj) or inspect.isroutine(obj):
                self.func.append(obj_name)
            elif isinstance(obj, Exception):
                self.excepts.append(obj_name)
            elif inspect.isclass(obj):
                self.classes.append((obj_name, obj))

        self.func.sort()
        self.excepts.sort()
        self.classes.sort()

    def __methods(self, cls):
        """Returns the methods and data of the class"""

        methods = []
        data = []

        for name, kind, defined, obj in inspect.classify_class_attrs(cls):
            if defined != cls:
                pass  # Inherited method
            elif name.startswith("__") \
               and name not in ["__init__"]:
                pass
            elif kind in ["method", "static method", "class method"]:
                methods.append(name)
            elif kind in ["property", "data"]:
                data.append(name)
            else:
                print "Unknown kind (%s) for %s.%s" % (
                    kind, defined.__name__, name)

        methods.sort()
        data.sort()
        return (data, methods)

    def generate_rest(self):
        """Generate a REST file for the given module.
           The output should be processed by sphinx.
        """

        n = self.module.__name__
        fd = file("generated/%s.rst" % n, "w")
        fd.write(Inspect.module_header % {"module": n})

        if self.func:
            fd.write(Inspect.functions_header)
            for f in self.func:
                fd.write(Inspect.function_stub %
                         {"name": f, "module": n})

        if self.classes:
            fd.write(Inspect.classes_header)
            for name, c in self.classes:

                # Only show inheritance diagram if base classes are other
                # than just "object"

                inheritance = ""
                mro = inspect.getmro(c) # first member is always c
                if len(mro) > 2 \
                   or (len(mro) == 2
                       and mro[1].__name__ != "object"):
                    inheritance = \
                        ".. inheritance-diagram:: %s.%s" % (n, name)

                fd.write(Inspect.class_stub %
                   {"name": name,
                    "inheritance": inheritance,
                    "underscore": "^" * (len(name) + len(n) + 10),
                    "module": n})

                data, methods = self.__methods(c)

                for d in data:
                    mname = "%s.%s.%s" % (n, name, d)
                    fd.write(Inspect.data_stub %
                        {"name": mname,
                         "base_name": d,
                         "underscore": "*" * (len(d) + 8)})

                for m in methods:
                    mname = "%s.%s.%s" % (n, name, m)
                    fd.write(Inspect.method_stub %
                        {"name": mname,
                         "base_name": m,
                         "inheritance":
                            ".. inheritance-diagram:: %s.%s" % (n, c),
                         "underscore": "*" * (len(m) + 8)})

        if self.excepts:
            fd.write(Inspect.exceptions_header)
            for c in self.excepts:
                fd.write(Inspect.class_stub %
                   {"name": c,
                    "inheritance":
                        ".. inheritance-diagram:: %s.%s" % (n, c),
                    "underscore": "^" * (len(c) + len(n) + 10),
                    "module": n})


import GPS
Inspect(GPS).generate_rest()
GPS.exit()
