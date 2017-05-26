#from distutils.core import setup
#from distutils.extension import Extension
from Cython.Distutils import build_ext
import numpy

try:
    from setuptools import setup
    from setuptools import Extension
except ImportError:
    from distutils.core import setup
    from distutils.extension import Extension

setup(
  name = 'cagent',
  ext_modules=[
    Extension('cagent', ['cagent.pyx'],
                # language="c++",
                # libraries=["stdc++"]
                ),
    Extension('processorgroup', ['processorgroup.pyx'],
                # language="c++",
                # libraries=["stdc++"]
                include_dirs=[numpy.get_include()],
                )],
  cmdclass = {'build_ext': build_ext}
)




